/*
 *  Copyright 2014-2017 Frank Hunleth
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include <err.h>
#include <poll.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <unistd.h>

#include <arpa/inet.h>
#include <libmnl/libmnl.h>
#include <net/if_arp.h>
#include <net/if.h>
#include <net/route.h>
#include <linux/if.h>
#include <linux/netlink.h>
#include <linux/rtnetlink.h>

// In Ubuntu 16.04, it seems that the new compat logic handling is preventing
// IFF_LOWER_UP from being defined properly. It looks like a bug, so define it
// here so that this file compiles.  A scan of all Nerves platforms and Ubuntu
// 16.04 has IFF_LOWER_UP always being set to 0x10000. this being defined as
// 0x10000.
#define WORKAROUND_IFF_LOWER_UP (0x10000)

#define MACADDR_STR_LEN      18 // aa:bb:cc:dd:ee:ff and a null terminator

#include "erlcmd.h"

//#define DEBUG
#ifdef DEBUG
#define debug(...) do { fprintf(stderr, __VA_ARGS__); fprintf(stderr, "\r\n"); } while(0)
#else
#define debug(...)
#endif

struct netif {
    // NETLINK_ROUTE socket information
    struct mnl_socket *nl;
    int seq;

    // NETLINK_KOBJECT_UEVENT socket information
    struct mnl_socket *nl_uevent;

    // AF_INET socket for ioctls
    int inet_fd;

    // Netlink buffering
    char nlbuf[8192]; // See MNL_SOCKET_BUFFER_SIZE

    // Erlang request processing
    const char *req;
    int req_index;

    // Erlang response processing
    char resp[ERLCMD_BUF_SIZE];
    int resp_index;

    // Async response handling
    void (*response_callback)(struct netif *nb, int bytecount);
    void (*response_error_callback)(struct netif *nb, int err);
    unsigned int response_portid;
    int response_seq;

    // Holder of the most recently encounted errno.
    int last_error;
};

static void netif_init(struct netif *nb)
{
    memset(nb, 0, sizeof(*nb));
    nb->nl = mnl_socket_open(NETLINK_ROUTE);
    if (!nb->nl)
        err(EXIT_FAILURE, "mnl_socket_open (NETLINK_ROUTE)");

    if (mnl_socket_bind(nb->nl, RTMGRP_LINK, MNL_SOCKET_AUTOPID) < 0)
        err(EXIT_FAILURE, "mnl_socket_bind");

    nb->nl_uevent = mnl_socket_open(NETLINK_KOBJECT_UEVENT);
    if (!nb->nl_uevent)
        err(EXIT_FAILURE, "mnl_socket_open (NETLINK_KOBJECT_UEVENT)");

    // There is one single group in kobject over netlink
    if (mnl_socket_bind(nb->nl_uevent, (1<<0), MNL_SOCKET_AUTOPID) < 0)
        err(EXIT_FAILURE, "mnl_socket_bind");

    nb->inet_fd = socket(AF_INET, SOCK_DGRAM, 0);
    if (nb->inet_fd < 0)
        err(EXIT_FAILURE, "socket");

    nb->seq = 1;
}

static void netif_cleanup(struct netif *nb)
{
    mnl_socket_close(nb->nl);
    mnl_socket_close(nb->nl_uevent);
    nb->nl = NULL;
}

static void start_response(struct netif *nb)
{
    nb->resp_index = sizeof(uint16_t); // Space for payload size
    nb->resp[nb->resp_index++] = 'r'; // Indicate response
    ei_encode_version(nb->resp, &nb->resp_index);
}

static void send_response(struct netif *nb)
{
    debug("sending response: %d bytes", nb->resp_index);
    erlcmd_send(nb->resp, nb->resp_index);
    nb->resp_index = 0;
}

static int collect_if_attrs(const struct nlattr *attr, void *data)
{
    const struct nlattr **tb = data;
    int type = mnl_attr_get_type(attr);

    // Skip unsupported attributes in user-space
    if (mnl_attr_type_valid(attr, IFLA_MAX) < 0)
        return MNL_CB_OK;

    // Only save supported attributes (see encode logic)
    switch (type) {
    case IFLA_MTU:
    case IFLA_IFNAME:
    case IFLA_ADDRESS:
    case IFLA_BROADCAST:
    case IFLA_LINK:
    case IFLA_OPERSTATE:
    case IFLA_STATS:
        tb[type] = attr;
        break;

    default:
        break;
    }
    return MNL_CB_OK;
}


static int string_to_macaddr(const char *str, unsigned char *mac)
{
    if (sscanf(str,
               "%02hhx:%02hhx:%02hhx:%02hhx:%02hhx:%02hhx",
               &mac[0], &mac[1], &mac[2],
               &mac[3], &mac[4], &mac[5]) != 6)
        return -1;
    else
        return 0;
}
static int macaddr_to_string(const unsigned char *mac, char *str)
{
    snprintf(str, MACADDR_STR_LEN,
             "%02x:%02x:%02x:%02x:%02x:%02x",
             mac[0], mac[1], mac[2],
             mac[3], mac[4], mac[5]);
    return 0;
}

static void encode_kv_long(struct netif *nb, const char *key, long value)
{
    ei_encode_atom(nb->resp, &nb->resp_index, key);
    ei_encode_long(nb->resp, &nb->resp_index, value);
}

static void encode_kv_ulong(struct netif *nb, const char *key, unsigned long value)
{
    ei_encode_atom(nb->resp, &nb->resp_index, key);
    ei_encode_ulong(nb->resp, &nb->resp_index, value);
}
static void encode_kv_bool(struct netif *nb, const char *key, int value)
{
    ei_encode_atom(nb->resp, &nb->resp_index, key);
    ei_encode_boolean(nb->resp, &nb->resp_index, value);
}
static void encode_string(char *buf, int *index, const char *str)
{
    // Encode strings as binaries so that we get Elixir strings
    // NOTE: the strings that we encounter here are expected to be ASCII to
    //       my knowledge
    ei_encode_binary(buf, index, str, strlen(str));
}
static void encode_kv_string(struct netif *nb, const char *key, const char *str)
{
    ei_encode_atom(nb->resp, &nb->resp_index, key);
    encode_string(nb->resp, &nb->resp_index, str);
}

static void encode_kv_macaddr(struct netif *nb, const char *key, const unsigned char *macaddr)
{
    ei_encode_atom(nb->resp, &nb->resp_index, key);

    char macaddr_str[MACADDR_STR_LEN];

    // Only handle 6 byte mac addresses (to my knowledge, this is the only case)
    macaddr_to_string(macaddr, macaddr_str);

    encode_string(nb->resp, &nb->resp_index, macaddr_str);
}

static void encode_kv_stats(struct netif *nb, const char *key, struct nlattr *attr)
{
    struct rtnl_link_stats *stats = (struct rtnl_link_stats *) mnl_attr_get_payload(attr);

    ei_encode_atom(nb->resp, &nb->resp_index, key);
    ei_encode_map_header(nb->resp, &nb->resp_index, 10);
    encode_kv_ulong(nb, "rx_packets", stats->rx_packets);
    encode_kv_ulong(nb, "tx_packets", stats->tx_packets);
    encode_kv_ulong(nb, "rx_bytes", stats->rx_bytes);
    encode_kv_ulong(nb, "tx_bytes", stats->tx_bytes);
    encode_kv_ulong(nb, "rx_errors", stats->rx_errors);
    encode_kv_ulong(nb, "tx_errors", stats->tx_errors);
    encode_kv_ulong(nb, "rx_dropped", stats->rx_dropped);
    encode_kv_ulong(nb, "tx_dropped", stats->tx_dropped);
    encode_kv_ulong(nb, "multicast", stats->multicast);
    encode_kv_ulong(nb, "collisions", stats->collisions);
}

static void encode_kv_operstate(struct netif *nb, int operstate)
{
    ei_encode_atom(nb->resp, &nb->resp_index, "operstate");

    // Refer to RFC2863 for state descriptions (or the kernel docs)
    const char *operstate_atom;
    switch (operstate) {
    default:
    case IF_OPER_UNKNOWN:        operstate_atom = "unknown"; break;
    case IF_OPER_NOTPRESENT:     operstate_atom = "notpresent"; break;
    case IF_OPER_DOWN:           operstate_atom = "down"; break;
    case IF_OPER_LOWERLAYERDOWN: operstate_atom = "lowerlayerdown"; break;
    case IF_OPER_TESTING:        operstate_atom = "testing"; break;
    case IF_OPER_DORMANT:        operstate_atom = "dormant"; break;
    case IF_OPER_UP:             operstate_atom = "up"; break;
    }
    ei_encode_atom(nb->resp, &nb->resp_index, operstate_atom);
}

static int netif_build_ifinfo(const struct nlmsghdr *nlh, void *data)
{
    struct netif *nb = (struct netif *) data;
    struct nlattr *tb[IFLA_MAX + 1];
    memset(tb, 0, sizeof(tb));
    struct ifinfomsg *ifm = mnl_nlmsg_get_payload(nlh);

    if (mnl_attr_parse(nlh, sizeof(*ifm), collect_if_attrs, tb) != MNL_CB_OK) {
        debug("Error from mnl_attr_parse");
        return MNL_CB_ERROR;
    }

    int count = 7; // Number of fields that we always encode
    int i;
    for (i = 0; i <= IFLA_MAX; i++)
        if (tb[i])
            count++;

    ei_encode_map_header(nb->resp, &nb->resp_index, count);

    encode_kv_long(nb, "index", ifm->ifi_index);

    ei_encode_atom(nb->resp, &nb->resp_index, "type");
    ei_encode_atom(nb->resp, &nb->resp_index, ifm->ifi_type == ARPHRD_ETHER ? "ethernet" : "other");

    encode_kv_bool(nb, "is_up", ifm->ifi_flags & IFF_UP);
    encode_kv_bool(nb, "is_broadcast", ifm->ifi_flags & IFF_BROADCAST);
    encode_kv_bool(nb, "is_running", ifm->ifi_flags & IFF_RUNNING);
    encode_kv_bool(nb, "is_lower_up", ifm->ifi_flags & WORKAROUND_IFF_LOWER_UP);
    encode_kv_bool(nb, "is_multicast", ifm->ifi_flags & IFF_MULTICAST);

    if (tb[IFLA_MTU])
        encode_kv_ulong(nb, "mtu", mnl_attr_get_u32(tb[IFLA_MTU]));
    if (tb[IFLA_IFNAME])
        encode_kv_string(nb, "ifname", mnl_attr_get_str(tb[IFLA_IFNAME]));
    if (tb[IFLA_ADDRESS])
        encode_kv_macaddr(nb, "mac_address", mnl_attr_get_payload(tb[IFLA_ADDRESS]));
    if (tb[IFLA_BROADCAST])
        encode_kv_macaddr(nb, "mac_broadcast", mnl_attr_get_payload(tb[IFLA_BROADCAST]));
    if (tb[IFLA_LINK])
        encode_kv_ulong(nb, "link", mnl_attr_get_u32(tb[IFLA_LINK]));
    if (tb[IFLA_OPERSTATE])
        encode_kv_operstate(nb, mnl_attr_get_u32(tb[IFLA_OPERSTATE]));
    if (tb[IFLA_STATS])
        encode_kv_stats(nb, "stats", tb[IFLA_STATS]);

    return MNL_CB_OK;
}

static void nl_uevent_process(struct netif *nb)
{
    int bytecount = mnl_socket_recvfrom(nb->nl_uevent, nb->nlbuf, sizeof(nb->nlbuf));
    if (bytecount <= 0)
        err(EXIT_FAILURE, "mnl_socket_recvfrom");

    // uevent messages are concatenated strings
    enum hotplug_operation {
        HOTPLUG_OPERATION_NONE = 0,
        HOTPLUG_OPERATION_ADD,
        HOTPLUG_OPERATION_MOVE,
        HOTPLUG_OPERATION_REMOVE
    } operation = HOTPLUG_OPERATION_NONE;

    const char *str = nb->nlbuf;
    if (strncmp(str, "add@", 4) == 0)
        operation = HOTPLUG_OPERATION_ADD;
    else if (strncmp(str, "move@", 5) == 0)
        operation = HOTPLUG_OPERATION_MOVE;
    else if (strncmp(str, "remove@", 7) == 0)
        operation = HOTPLUG_OPERATION_REMOVE;
    else
        return; // Not interested in this message.

    const char *str_end = str + bytecount;
    str += strlen(str) + 1;

    // Extract the fields of interest
    const char *ifname = NULL;
    const char *subsystem = NULL;
    const char *ifindex = NULL;
    for (;str < str_end; str += strlen(str) + 1) {
        if (strncmp(str, "INTERFACE=", 10) == 0)
            ifname = str + 10;
        else if (strncmp(str, "SUBSYSTEM=", 10) == 0)
            subsystem = str + 10;
        else if (strncmp(str, "IFINDEX=", 8) == 0)
            ifindex = str + 8;
    }

    // Check that we have the required fields that this is a
    // "net" subsystem event. If yes, send the notification.
    if (ifname && subsystem && ifindex && strcmp(subsystem, "net") == 0) {
        nb->resp_index = sizeof(uint16_t); // Skip over payload size
        nb->resp[nb->resp_index++] = 'n';
        ei_encode_version(nb->resp, &nb->resp_index);

        ei_encode_tuple_header(nb->resp, &nb->resp_index, 2);

        switch (operation) {
        case HOTPLUG_OPERATION_ADD:
            ei_encode_atom(nb->resp, &nb->resp_index, "ifadded");
            break;
        case HOTPLUG_OPERATION_MOVE:
            ei_encode_atom(nb->resp, &nb->resp_index, "ifrenamed");
            break;
        case HOTPLUG_OPERATION_REMOVE:
        default: // Silence warning
            ei_encode_atom(nb->resp, &nb->resp_index, "ifremoved");
            break;
        }

        ei_encode_map_header(nb->resp, &nb->resp_index, 2);

        encode_kv_long(nb, "index", strtol(ifindex, NULL, 0));
        encode_kv_string(nb, "ifname", ifname);

        erlcmd_send(nb->resp, nb->resp_index);
    }
}

static void handle_notification(struct netif *nb, int bytecount)
{
    // Create the notification
    nb->resp_index = sizeof(uint16_t); // Skip over payload size
    nb->resp[nb->resp_index++] = 'n';
    ei_encode_version(nb->resp, &nb->resp_index);

    ei_encode_tuple_header(nb->resp, &nb->resp_index, 2);

    // Currently, the only notifications are interface changes.
    ei_encode_atom(nb->resp, &nb->resp_index, "ifchanged");
    if (mnl_cb_run(nb->nlbuf, bytecount, 0, 0, netif_build_ifinfo, nb) <= 0)
        err(EXIT_FAILURE, "mnl_cb_run");

    erlcmd_send(nb->resp, nb->resp_index);
}

static void handle_async_response(struct netif *nb, int bytecount)
{
    nb->response_callback(nb, bytecount);
    nb->response_callback = NULL;
    nb->response_error_callback = NULL;
}

static void handle_async_response_error(struct netif *nb, int err)
{
    nb->response_error_callback(nb, err);
    nb->response_callback = NULL;
    nb->response_error_callback = NULL;
}

static void nl_route_process(struct netif *nb)
{
    int bytecount = mnl_socket_recvfrom(nb->nl, nb->nlbuf, sizeof(nb->nlbuf));
    if (bytecount <= 0)
        err(EXIT_FAILURE, "mnl_socket_recvfrom");

    // Check if there's an async response on the saved sequence number and port id.
    // If not or if the message is not expected, then it's a notification.
    if (nb->response_callback != NULL) {
        int rc = mnl_cb_run(nb->nlbuf, bytecount, nb->response_seq, nb->response_portid, NULL, NULL);
        if (rc == MNL_CB_OK)
            handle_async_response(nb, bytecount);
        else if (rc == MNL_CB_ERROR && errno != ESRCH && errno != EPROTO)
            handle_async_response_error(nb, errno);
        else
            handle_notification(nb, bytecount);
    } else
        handle_notification(nb, bytecount);
}

static void netif_handle_interfaces(struct netif *nb)
{
    struct if_nameindex *if_ni = if_nameindex();
    if (if_ni == NULL)
        err(EXIT_FAILURE, "if_nameindex");

    start_response(nb);
    for (struct if_nameindex *i = if_ni;
         ! (i->if_index == 0 && i->if_name == NULL);
         i++) {
        debug("Found interface %s.", i->if_name);
        ei_encode_list_header(nb->resp, &nb->resp_index, 1);
        encode_string(nb->resp, &nb->resp_index, i->if_name);
    }

    if_freenameindex(if_ni);

    ei_encode_empty_list(nb->resp, &nb->resp_index);
    send_response(nb);
}

static void netif_handle_status_callback(struct netif *nb, int bytecount)
{
    start_response(nb);

    int original_resp_index = nb->resp_index;

    ei_encode_tuple_header(nb->resp, &nb->resp_index, 2);
    ei_encode_atom(nb->resp, &nb->resp_index, "ok");
    if (mnl_cb_run(nb->nlbuf, bytecount, nb->response_seq, nb->response_portid, netif_build_ifinfo, nb) < 0) {
        debug("error from or mnl_cb_run?");
        nb->resp_index = original_resp_index;
        erlcmd_encode_errno_error(nb->resp, &nb->resp_index, errno);
    }

    send_response(nb);
}

static void netif_handle_status_error_callback(struct netif *nb, int err)
{
    start_response(nb);
    erlcmd_encode_errno_error(nb->resp, &nb->resp_index, err);
    send_response(nb);
}

static void netif_handle_status(struct netif *nb,
                                    const char *ifname)
{
    struct nlmsghdr *nlh;
    struct ifinfomsg *ifi;
    unsigned int seq;

    nlh = mnl_nlmsg_put_header(nb->nlbuf);
    nlh->nlmsg_type = RTM_GETLINK;
    nlh->nlmsg_flags = NLM_F_REQUEST;
    nlh->nlmsg_seq = seq = nb->seq++;

    ifi = mnl_nlmsg_put_extra_header(nlh, sizeof(struct ifinfomsg));
    ifi->ifi_family = AF_UNSPEC;
    ifi->ifi_type = ARPHRD_ETHER;
    ifi->ifi_index = 0;
    ifi->ifi_flags = 0;
    ifi->ifi_change = 0xffffffff;

    mnl_attr_put_str(nlh, IFLA_IFNAME, ifname);

    if (mnl_socket_sendto(nb->nl, nlh, nlh->nlmsg_len) < 0)
        err(EXIT_FAILURE, "mnl_socket_send");

    nb->response_callback = netif_handle_status_callback;
    nb->response_error_callback = netif_handle_status_error_callback;
    nb->response_portid = mnl_socket_get_portid(nb->nl);
    nb->response_seq = seq;
}

static void netif_set_ifflags(struct netif *nb,
                                  const char *ifname,
                                  uint32_t flags,
                                  uint32_t mask)
{
    struct ifreq ifr;

    start_response(nb);

    strncpy(ifr.ifr_name, ifname, IFNAMSIZ);
    if (ioctl(nb->inet_fd, SIOCGIFFLAGS, &ifr) < 0) {
        debug("SIOCGIFFLAGS error: %s", strerror(errno));
        erlcmd_encode_errno_error(nb->resp, &nb->resp_index, errno);
        send_response(nb);
        return;
    }

    if ((ifr.ifr_flags ^ flags) & mask) {
        ifr.ifr_flags = (ifr.ifr_flags & ~mask) | (mask & flags);
        if (ioctl(nb->inet_fd, SIOCSIFFLAGS, &ifr)) {
            debug("SIOCGIFFLAGS error: %s", strerror(errno));
            erlcmd_encode_errno_error(nb->resp, &nb->resp_index, errno);
            send_response(nb);
            return;
        }
    }
    erlcmd_encode_ok(nb->resp, &nb->resp_index);
    send_response(nb);
}

static int collect_route_attrs(const struct nlattr *attr, void *data)
{
    const struct nlattr **tb = data;
    int type = mnl_attr_get_type(attr);

    // Skip unsupported attributes in user-space
    if (mnl_attr_type_valid(attr, RTA_MAX) < 0)
        return MNL_CB_OK;

    tb[type] = attr;
    return MNL_CB_OK;
}

struct fdg_data {
    int oif;
    char *result;
};

static int check_default_gateway(const struct nlmsghdr *nlh, void *data)
{
    struct nlattr *tb[RTA_MAX + 1];
    memset(tb, 0, sizeof(tb));
    struct rtmsg *rm = mnl_nlmsg_get_payload(nlh);
    mnl_attr_parse(nlh, sizeof(*rm), collect_route_attrs, tb);

    struct fdg_data *fdg = (struct fdg_data *) data;
    if (rm->rtm_scope == 0 &&
            tb[RTA_OIF] &&
            (int) mnl_attr_get_u32(tb[RTA_OIF]) == fdg->oif &&
            tb[RTA_GATEWAY]) {
        // Found it.
        inet_ntop(AF_INET, mnl_attr_get_payload(tb[RTA_GATEWAY]), fdg->result, INET_ADDRSTRLEN);
    }

    return MNL_CB_OK;
}

static void find_default_gateway(struct netif *nb,
                                int oif,
                                char *result)
{
    struct nlmsghdr *nlh;
    struct rtmsg *rtm;
    unsigned int seq;

    nlh = mnl_nlmsg_put_header(nb->nlbuf);
    nlh->nlmsg_type = RTM_GETROUTE;
    nlh->nlmsg_flags = NLM_F_REQUEST | NLM_F_DUMP;
    nlh->nlmsg_seq = seq = nb->seq++;

    rtm = mnl_nlmsg_put_extra_header(nlh, sizeof(struct rtmsg));
    rtm->rtm_family = AF_INET;

    if (mnl_socket_sendto(nb->nl, nlh, nlh->nlmsg_len) < 0)
        err(EXIT_FAILURE, "mnl_socket_send");

    unsigned int portid = mnl_socket_get_portid(nb->nl);

    struct fdg_data fdg;
    fdg.oif = oif;
    fdg.result = result;
    *fdg.result = '\0';

    ssize_t ret = mnl_socket_recvfrom(nb->nl, nb->nlbuf, sizeof(nb->nlbuf));
    while (ret > 0) {
        ret = mnl_cb_run(nb->nlbuf, ret, seq, portid, check_default_gateway, &fdg);
        if (ret <= MNL_CB_STOP)
            break;
        ret = mnl_socket_recvfrom(nb->nl, nb->nlbuf, sizeof(nb->nlbuf));
    }
    if (ret == -1)
        err(EXIT_FAILURE, "mnl_socket_recvfrom");
}

struct ip_setting_handler {
    const char *name;
    int (*prep)(const struct ip_setting_handler *handler, struct netif *nb, void **context);
    int (*set)(const struct ip_setting_handler *handler, struct netif *nb, const char *ifname, void *context);
    int (*get)(const struct ip_setting_handler *handler, struct netif *nb, const char *ifname);

    // data for handlers
    int ioctl_set;
    int ioctl_get;
};

static int prep_mac_address_ioctl(const struct ip_setting_handler *handler, struct netif *nb, void **context);
static int set_mac_address_ioctl(const struct ip_setting_handler *handler, struct netif *nb, const char *ifname, void *context);
static int get_mac_address_ioctl(const struct ip_setting_handler *handler, struct netif *nb, const char *ifname);
static int prep_ipaddr_ioctl(const struct ip_setting_handler *handler, struct netif *nb, void **context);
static int set_ipaddr_ioctl(const struct ip_setting_handler *handler, struct netif *nb, const char *ifname, void *context);
static int get_ipaddr_ioctl(const struct ip_setting_handler *handler, struct netif *nb, const char *ifname);
static int prep_default_gateway(const struct ip_setting_handler *handler, struct netif *nb, void **context);
static int set_default_gateway(const struct ip_setting_handler *handler, struct netif *nb, const char *ifname, void *context);
static int get_default_gateway(const struct ip_setting_handler *handler, struct netif *nb, const char *ifname);

// These handlers are listed in the order that they should be invoked when
// configuring the interface. For example, "ipv4_gateway" is listed at the end
// so that it is set after the address and subnet_mask. If this is not done,
// setting the gateway may fail since Linux thinks that it is on the wrong subnet.
static const struct ip_setting_handler handlers[] = {
    { "ipv4_address", prep_ipaddr_ioctl, set_ipaddr_ioctl, get_ipaddr_ioctl, SIOCSIFADDR, SIOCGIFADDR },
    { "ipv4_subnet_mask", prep_ipaddr_ioctl, set_ipaddr_ioctl, get_ipaddr_ioctl, SIOCSIFNETMASK, SIOCGIFNETMASK },
    { "ipv4_broadcast", prep_ipaddr_ioctl, set_ipaddr_ioctl, get_ipaddr_ioctl, SIOCSIFBRDADDR, SIOCGIFBRDADDR },
    { "ipv4_gateway", prep_default_gateway, set_default_gateway, get_default_gateway, 0, 0 },
    { "mac_address", prep_mac_address_ioctl, set_mac_address_ioctl, get_mac_address_ioctl, SIOCSIFHWADDR, SIOCGIFHWADDR },
};
#define HANDLER_COUNT (sizeof(handlers) / sizeof(handlers[0]))

static int prep_mac_address_ioctl(const struct ip_setting_handler *handler, struct netif *nb, void **context)
{
    char macaddr_str[MACADDR_STR_LEN];
    if (erlcmd_decode_string(nb->req, &nb->req_index, macaddr_str, sizeof(macaddr_str)) < 0)
        errx(EXIT_FAILURE, "mac address parameter required for '%s'", handler->name);

    // Be forgiving and if the user specifies an empty IP address, just skip
    // this request.
    if (macaddr_str[0] == '\0')
        *context = NULL;
    else
        *context = strdup(macaddr_str);

    return 0;
}


static int set_mac_address_ioctl(const struct ip_setting_handler *handler, struct netif *nb, const char *ifname, void *context)
{
    const char *macaddr_str = (const char *) context;

    struct ifreq ifr;
    memset(&ifr, 0, sizeof(ifr));
    strncpy(ifr.ifr_name, ifname, IFNAMSIZ);

    struct sockaddr_in *addr = (struct sockaddr_in *) &ifr.ifr_addr;
    addr->sin_family = AF_UNIX;
    unsigned char *mac = (unsigned char *) &ifr.ifr_hwaddr.sa_data;
    if (string_to_macaddr(macaddr_str, mac) < 0) {
        debug("Bad MAC address for '%s': %s", handler->name, macaddr_str);
        nb->last_error = EINVAL;
        return -1;
    }

    if (ioctl(nb->inet_fd, handler->ioctl_set, &ifr) < 0) {
        debug("ioctl(0x%04x) failed for setting '%s': %s", handler->ioctl_set, handler->name, strerror(errno));
        nb->last_error = errno;
        return -1;
    }

    return 0;
}

static int get_mac_address_ioctl(const struct ip_setting_handler *handler, struct netif *nb, const char *ifname)
{
    struct ifreq ifr;
    memset(&ifr, 0, sizeof(ifr));
    strncpy(ifr.ifr_name, ifname, IFNAMSIZ);

    if (ioctl(nb->inet_fd, handler->ioctl_get, &ifr) < 0) {
        debug("ioctl(0x%04x) failed for getting '%s': %s", handler->ioctl_get, handler->name, strerror(errno));
        nb->last_error = errno;
        return -1;
    }

    struct sockaddr_in *addr = (struct sockaddr_in *) &ifr.ifr_addr;
    if (addr->sin_family == AF_UNIX) {
        encode_kv_macaddr(nb, handler->name, (unsigned char *) &ifr.ifr_hwaddr.sa_data);
    } else {
        debug("got unexpected sin_family %d for '%s'", addr->sin_family, handler->name);
        nb->last_error = EINVAL;
        return -1;
    }
    return 0;
}

static int prep_ipaddr_ioctl(const struct ip_setting_handler *handler, struct netif *nb, void **context)
{
    char ipaddr[INET_ADDRSTRLEN];
    if (erlcmd_decode_string(nb->req, &nb->req_index, ipaddr, INET_ADDRSTRLEN) < 0)
        errx(EXIT_FAILURE, "ip address parameter required for '%s'", handler->name);

    // Be forgiving and if the user specifies an empty IP address, just skip
    // this request.
    if (ipaddr[0] == '\0')
        *context = NULL;
    else
        *context = strdup(ipaddr);

    return 0;
}

static int set_ipaddr_ioctl(const struct ip_setting_handler *handler, struct netif *nb, const char *ifname, void *context)
{
    const char *ipaddr = (const char *) context;

    struct ifreq ifr;
    memset(&ifr, 0, sizeof(ifr));
    strncpy(ifr.ifr_name, ifname, IFNAMSIZ);

    struct sockaddr_in *addr = (struct sockaddr_in *) &ifr.ifr_addr;
    addr->sin_family = AF_INET;
    if (inet_pton(AF_INET, ipaddr, &addr->sin_addr) <= 0) {
        debug("Bad IP address for '%s': %s", handler->name, ipaddr);
        nb->last_error = EINVAL;
        return -1;
    }

    if (ioctl(nb->inet_fd, handler->ioctl_set, &ifr) < 0) {
        debug("ioctl(0x%04x) failed for setting '%s': %s", handler->ioctl_set, handler->name, strerror(errno));
        nb->last_error = errno;
        return -1;
    }

    return 0;
}

static int get_ipaddr_ioctl(const struct ip_setting_handler *handler, struct netif *nb, const char *ifname)
{
    struct ifreq ifr;
    memset(&ifr, 0, sizeof(ifr));
    strncpy(ifr.ifr_name, ifname, IFNAMSIZ);

    if (ioctl(nb->inet_fd, handler->ioctl_get, &ifr) < 0) {
        debug("ioctl(0x%04x) failed for getting '%s': %s. Skipping...", handler->ioctl_get, handler->name, strerror(errno));
        encode_kv_string(nb, handler->name, "");
        return 0;
    }

    struct sockaddr_in *addr = (struct sockaddr_in *) &ifr.ifr_addr;
    if (addr->sin_family == AF_INET) {
        char addrstr[INET_ADDRSTRLEN];
        if (!inet_ntop(addr->sin_family, &addr->sin_addr, addrstr, sizeof(addrstr))) {
            debug("inet_ntop failed for '%s'? : %s", handler->name, strerror(errno));
            nb->last_error = errno;
            return -1;
        }
        encode_kv_string(nb, handler->name, addrstr);
    } else {
        debug("got unexpected sin_family %d for '%s'", addr->sin_family, handler->name);
        nb->last_error = EINVAL;
        return -1;
    }
    return 0;
}

static int remove_all_gateways(struct netif *nb, const char *ifname)
{
    struct rtentry route;
    memset(&route, 0, sizeof(route));

    struct sockaddr_in *addr = (struct sockaddr_in *) &route.rt_gateway;
    addr->sin_family = AF_INET;
    addr->sin_addr.s_addr = INADDR_ANY;

    addr = (struct sockaddr_in*) &route.rt_dst;
    addr->sin_family = AF_INET;
    addr->sin_addr.s_addr = INADDR_ANY;

    addr = (struct sockaddr_in*) &route.rt_genmask;
    addr->sin_family = AF_INET;
    addr->sin_addr.s_addr = INADDR_ANY;

    route.rt_dev = (char *) ifname;
    route.rt_flags = RTF_GATEWAY;
    route.rt_metric = 0;

    // There may be more than one gateway. Remove all
    // of them.
    for (;;) {
        int rc = ioctl(nb->inet_fd, SIOCDELRT, &route);
        if (rc < 0) {
            if (errno == ESRCH) {
                return 0;
            } else {
                nb->last_error = errno;
                return -1;
            }
        }
    }
}

static int add_default_gateway(struct netif *nb, const char *ifname, const char *gateway_ip)
{
    struct rtentry route;
    memset(&route, 0, sizeof(route));

    struct sockaddr_in *addr = (struct sockaddr_in *)&route.rt_gateway;
    memset(addr, 0, sizeof(struct sockaddr_in));
    addr->sin_family = AF_INET;
    if (inet_pton(AF_INET, gateway_ip, &addr->sin_addr) <= 0) {
        debug("Bad IP address for the default gateway: %s", gateway_ip);
        nb->last_error = EINVAL;
        return -1;
    }

    addr = (struct sockaddr_in*) &route.rt_dst;
    memset(addr, 0, sizeof(struct sockaddr_in));
    addr->sin_family = AF_INET;
    addr->sin_addr.s_addr = INADDR_ANY;

    addr = (struct sockaddr_in*) &route.rt_genmask;
    memset(addr, 0, sizeof(struct sockaddr_in));
    addr->sin_family = AF_INET;
    addr->sin_addr.s_addr = INADDR_ANY;

    route.rt_dev = (char *) ifname;
    route.rt_flags = RTF_UP | RTF_GATEWAY;
    route.rt_metric = 0;

    int rc = ioctl(nb->inet_fd, SIOCADDRT, &route);
    if (rc < 0 && errno != EEXIST) {
        nb->last_error = errno;
        return -1;
    }
    return 0;
}

static int prep_default_gateway(const struct ip_setting_handler *handler, struct netif *nb, void **context)
{
    char gateway[INET_ADDRSTRLEN];
    if (erlcmd_decode_string(nb->req, &nb->req_index, gateway, INET_ADDRSTRLEN) < 0)
        errx(EXIT_FAILURE, "ip address parameter required for '%s'", handler->name);

    *context = strdup(gateway);
    return 0;
}

static int set_default_gateway(const struct ip_setting_handler *handler, struct netif *nb, const char *ifname, void *context)
{
    (void) handler;
    const char *gateway = context;

    // Before one can be set, any configured gateways need to be removed.
    if (remove_all_gateways(nb, ifname) < 0)
        return -1;

    // If no gateway was specified, then we're done.
    if (*gateway == '\0')
        return 0;

    return add_default_gateway(nb, ifname, gateway);
}

static int ifname_to_index(struct netif *nb, const char *ifname)
{
    struct ifreq ifr;
    memset(&ifr, 0, sizeof(ifr));
    strncpy(ifr.ifr_name, ifname, IFNAMSIZ);

    if (ioctl(nb->inet_fd, SIOCGIFINDEX, &ifr) < 0) {
        nb->last_error = errno;
        return -1;
    }
    return ifr.ifr_ifindex;
}

static int get_default_gateway(const struct ip_setting_handler *handler, struct netif *nb, const char *ifname)
{
    int oif = ifname_to_index(nb, ifname);
    if (oif < 0)
        return -1;

    char gateway_ip[INET_ADDRSTRLEN];
    find_default_gateway(nb, oif, gateway_ip);

    // If the gateway isn't found, then the empty string is what we want.
    encode_kv_string(nb, handler->name, gateway_ip);
    return 0;
}

static void netif_handle_get(struct netif *nb,
                                 const char *ifname)
{
    start_response(nb);
    int original_resp_index = nb->resp_index;

    ei_encode_tuple_header(nb->resp, &nb->resp_index, 2);
    ei_encode_atom(nb->resp, &nb->resp_index, "ok");
    ei_encode_map_header(nb->resp, &nb->resp_index, HANDLER_COUNT);

    nb->last_error = 0;
    for (size_t i = 0; i < HANDLER_COUNT; i++) {
        const struct ip_setting_handler *handler = &handlers[i];
        if (handler->get(handler, nb, ifname) < 0)
            break;
    }

    if (nb->last_error) {
        nb->resp_index = original_resp_index;
        erlcmd_encode_errno_error(nb->resp, &nb->resp_index, nb->last_error);
    }
    send_response(nb);
}

static const struct ip_setting_handler *find_handler(const char *name)
{
    for (size_t i = 0; i < HANDLER_COUNT; i++) {
        const struct ip_setting_handler *handler = &handlers[i];
        if (strcmp(handler->name, name) == 0)
            return handler;
    }
    return NULL;
}

static void netif_handle_set(struct netif *nb,
                             const char *ifname)
{
    nb->last_error = 0;

    start_response(nb);

    int arity;
    if (ei_decode_map_header(nb->req, &nb->req_index, &arity) < 0)
        errx(EXIT_FAILURE, "setting attributes requires a map");

    void *handler_context[HANDLER_COUNT];
    memset(handler_context, 0, sizeof(handler_context));

    // Parse all options
    for (int i = 0; i < arity && nb->last_error == 0; i++) {
        char name[32];
        if (erlcmd_decode_atom(nb->req, &nb->req_index, name, sizeof(name)) < 0)
            errx(EXIT_FAILURE, "error in map encoding");

        // Look up the option. If we don't know it, silently ignore it so that
        // the caller can pass in maps that contain options for other code.
        const struct ip_setting_handler *handler = find_handler(name);
        if (handler)
            handler->prep(handler, nb, &handler_context[handler - handlers]);
        else
            ei_skip_term(nb->req, &nb->req_index);
    }

    // If no errors, then set everything
    if (!nb->last_error) {
        // Order is important: see note on handlers
        for (size_t i = 0; i < HANDLER_COUNT; i++) {
            if (handler_context[i]) {
                handlers[i].set(&handlers[i], nb, ifname, handler_context[i]);
                free(handler_context[i]);
            }
        }
    }

    // Encode and send the response
    if (nb->last_error)
        erlcmd_encode_errno_error(nb->resp, &nb->resp_index, nb->last_error);
    else
        erlcmd_encode_ok(nb->resp, &nb->resp_index);

    send_response(nb);
}

static void netif_request_handler(const char *req, void *cookie)
{
    struct netif *nb = (struct netif *) cookie;
    char ifname[IFNAMSIZ];

    // Commands are of the form {Command, Arguments}:
    // { atom(), term() }
    nb->req_index = sizeof(uint16_t);
    nb->req = req;
    if (ei_decode_version(nb->req, &nb->req_index, NULL) < 0)
        errx(EXIT_FAILURE, "Message version issue?");

    int arity;
    if (ei_decode_tuple_header(nb->req, &nb->req_index, &arity) < 0 ||
            arity != 2)
        errx(EXIT_FAILURE, "expecting {cmd, args} tuple");

    char cmd[MAXATOMLEN];
    if (ei_decode_atom(nb->req, &nb->req_index, cmd) < 0)
        errx(EXIT_FAILURE, "expecting command atom");

    if (strcmp(cmd, "interfaces") == 0) {
        debug("interfaces");
        netif_handle_interfaces(nb);
    } else if (strcmp(cmd, "status") == 0) {
        if (erlcmd_decode_string(nb->req, &nb->req_index, ifname, IFNAMSIZ) < 0)
            errx(EXIT_FAILURE, "status requires ifname");
        debug("ifinfo: %s", ifname);
        netif_handle_status(nb, ifname);
    } else if (strcmp(cmd, "ifup") == 0) {
        if (erlcmd_decode_string(nb->req, &nb->req_index, ifname, IFNAMSIZ) < 0)
            errx(EXIT_FAILURE, "ifup requires ifname");
        debug("ifup: %s", ifname);
        netif_set_ifflags(nb, ifname, IFF_UP, IFF_UP);
    } else if (strcmp(cmd, "ifdown") == 0) {
        if (erlcmd_decode_string(nb->req, &nb->req_index, ifname, IFNAMSIZ) < 0)
            errx(EXIT_FAILURE, "ifdown requires ifname");
        debug("ifdown: %s", ifname);
        netif_set_ifflags(nb, ifname, 0, IFF_UP);
    } else if (strcmp(cmd, "setup") == 0) {
        if (ei_decode_tuple_header(nb->req, &nb->req_index, &arity) < 0 ||
                arity != 2 ||
                erlcmd_decode_string(nb->req, &nb->req_index, ifname, IFNAMSIZ) < 0)
            errx(EXIT_FAILURE, "setup requires {ifname, parameters}");
        debug("set: %s", ifname);
        netif_handle_set(nb, ifname);
    } else if (strcmp(cmd, "settings") == 0) {
        if (erlcmd_decode_string(nb->req, &nb->req_index, ifname, IFNAMSIZ) < 0)
            errx(EXIT_FAILURE, "settings requires ifname");
        debug("get: %s", ifname);
        netif_handle_get(nb, ifname);
    } else
        errx(EXIT_FAILURE, "unknown command: %s", cmd);
}

int main(int argc, char *argv[])
{
    (void) argc;
    (void) argv;

    struct netif nb;
    netif_init(&nb);

    struct erlcmd handler;
    erlcmd_init(&handler, netif_request_handler, &nb);

    for (;;) {
        struct pollfd fdset[3];

        fdset[0].fd = STDIN_FILENO;
        fdset[0].events = POLLIN;
        fdset[0].revents = 0;

        fdset[1].fd = mnl_socket_get_fd(nb.nl);
        fdset[1].events = POLLIN;
        fdset[1].revents = 0;

        fdset[2].fd = mnl_socket_get_fd(nb.nl_uevent);
        fdset[2].events = POLLIN;
        fdset[2].revents = 0;

        int rc = poll(fdset, 3, -1);
        if (rc < 0) {
            // Retry if EINTR
            if (errno == EINTR)
                continue;

            err(EXIT_FAILURE, "poll");
        }

        if (fdset[0].revents & (POLLIN | POLLHUP))
            erlcmd_process(&handler);
        if (fdset[1].revents & (POLLIN | POLLHUP))
            nl_route_process(&nb);
        if (fdset[2].revents & (POLLIN | POLLHUP))
            nl_uevent_process(&nb);
    }

    netif_cleanup(&nb);
    return 0;
}
