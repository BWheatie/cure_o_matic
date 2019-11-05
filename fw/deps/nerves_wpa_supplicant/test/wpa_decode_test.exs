defmodule WpaDecodeTest do
  use ExUnit.Case

  alias Nerves.WpaSupplicant.Messages

  test "responses" do
    assert Messages.decode_resp(:PING, "PONG  ") == :PONG

    assert Messages.decode_resp(:MIB, """
           dot11RSNAOptionImplemented=TRUE
           dot11RSNAPreauthenticationImplemented=TRUE
           dot11RSNAEnabled=FALSE
           dot11RSNAPreauthenticationEnabled=FALSE
           dot11RSNAConfigVersion=1
           dot11RSNAConfigPairwiseKeysSupported=5
           dot11RSNAConfigGroupCipherSize=128
           dot11RSNAConfigPMKLifetime=43200
           dot11RSNAConfigPMKReauthThreshold=70
           dot11RSNAConfigNumberOfPTKSAReplayCounters=1
           dot11RSNAConfigSATimeout=60
           dot11RSNAAuthenticationSuiteSelected=00-50-f2-2
           dot11RSNAPairwiseCipherSelected=00-50-f2-4
           dot11RSNAGroupCipherSelected=00-50-f2-4
           dot11RSNAPMKIDUsed=
           dot11RSNAAuthenticationSuiteRequested=00-50-f2-2
           dot11RSNAPairwiseCipherRequested=00-50-f2-4
           dot11RSNAGroupCipherRequested=00-50-f2-4
           dot11RSNAConfigNumberOfGTKSAReplayCounters=0
           dot11RSNA4WayHandshakeFailures=0
           dot1xSuppPaeState=5
           dot1xSuppHeldPeriod=60
           dot1xSuppAuthPeriod=30
           dot1xSuppStartPeriod=30
           dot1xSuppMaxStart=3
           dot1xSuppSuppControlledPortStatus=Authorized
           dot1xSuppBackendPaeState=2
           dot1xSuppEapolFramesRx=0
           dot1xSuppEapolFramesTx=440
           dot1xSuppEapolStartFramesTx=2
           dot1xSuppEapolLogoffFramesTx=0
           dot1xSuppEapolRespFramesTx=0
           dot1xSuppEapolReqIdFramesRx=0
           dot1xSuppEapolReqFramesRx=0
           dot1xSuppInvalidEapolFramesRx=0
           dot1xSuppEapLengthErrorFramesRx=0
           dot1xSuppLastEapolFrameVersion=0
           dot1xSuppLastEapolFrameSource=00:00:00:00:00:00
           """) == %{
             dot11RSNAOptionImplemented: true,
             dot11RSNAPreauthenticationImplemented: true,
             dot11RSNAEnabled: false,
             dot11RSNAPreauthenticationEnabled: false,
             dot11RSNAConfigVersion: 1,
             dot11RSNAConfigPairwiseKeysSupported: 5,
             dot11RSNAConfigGroupCipherSize: 128,
             dot11RSNAConfigPMKLifetime: 43200,
             dot11RSNAConfigPMKReauthThreshold: 70,
             dot11RSNAConfigNumberOfPTKSAReplayCounters: 1,
             dot11RSNAConfigSATimeout: 60,
             dot11RSNAAuthenticationSuiteSelected: "00-50-f2-2",
             dot11RSNAPairwiseCipherSelected: "00-50-f2-4",
             dot11RSNAGroupCipherSelected: "00-50-f2-4",
             dot11RSNAPMKIDUsed: nil,
             dot11RSNAAuthenticationSuiteRequested: "00-50-f2-2",
             dot11RSNAPairwiseCipherRequested: "00-50-f2-4",
             dot11RSNAGroupCipherRequested: "00-50-f2-4",
             dot11RSNAConfigNumberOfGTKSAReplayCounters: 0,
             dot11RSNA4WayHandshakeFailures: 0,
             dot1xSuppPaeState: 5,
             dot1xSuppHeldPeriod: 60,
             dot1xSuppAuthPeriod: 30,
             dot1xSuppStartPeriod: 30,
             dot1xSuppMaxStart: 3,
             dot1xSuppSuppControlledPortStatus: "Authorized",
             dot1xSuppBackendPaeState: 2,
             dot1xSuppEapolFramesRx: 0,
             dot1xSuppEapolFramesTx: 440,
             dot1xSuppEapolStartFramesTx: 2,
             dot1xSuppEapolLogoffFramesTx: 0,
             dot1xSuppEapolRespFramesTx: 0,
             dot1xSuppEapolReqIdFramesRx: 0,
             dot1xSuppEapolReqFramesRx: 0,
             dot1xSuppInvalidEapolFramesRx: 0,
             dot1xSuppEapLengthErrorFramesRx: 0,
             dot1xSuppLastEapolFrameVersion: 0,
             dot1xSuppLastEapolFrameSource: "00:00:00:00:00:00"
           }

    assert Messages.decode_resp(:STATUS, """
           bssid=02:00:01:02:03:04
           ssid=test network
           pairwise_cipher=CCMP
           group_cipher=CCMP
           key_mgmt=WPA-PSK
           wpa_state=COMPLETED
           ip_address=192.168.1.21
           Supplicant PAE state=AUTHENTICATED
           suppPortStatus=Authorized
           EAP state=SUCCESS
           """) == %{
             bssid: "02:00:01:02:03:04",
             ssid: "test network",
             pairwise_cipher: "CCMP",
             group_cipher: "CCMP",
             key_mgmt: "WPA-PSK",
             wpa_state: "COMPLETED",
             ip_address: "192.168.1.21",
             "Supplicant PAE state": "AUTHENTICATED",
             suppPortStatus: "Authorized",
             "EAP state": "SUCCESS"
           }

    assert Messages.decode_resp(:"STATUS-VERBOSE", """
           bssid=02:00:01:02:03:04
           ssid=test network
           id=0
           pairwise_cipher=CCMP
           group_cipher=CCMP
           key_mgmt=WPA-PSK
           wpa_state=COMPLETED
           ip_address=192.168.1.21
           Supplicant PAE state=AUTHENTICATED
           suppPortStatus=Authorized
           heldPeriod=60
           authPeriod=30
           startPeriod=30
           maxStart=3
           portControl=Auto
           Supplicant Backend state=IDLE
           EAP state=SUCCESS
           reqMethod=0
           methodState=NONE
           decision=COND_SUCC
           ClientTimeout=60
           """) == %{
             bssid: "02:00:01:02:03:04",
             ssid: "test network",
             id: 0,
             pairwise_cipher: "CCMP",
             group_cipher: "CCMP",
             key_mgmt: "WPA-PSK",
             wpa_state: "COMPLETED",
             ip_address: "192.168.1.21",
             "Supplicant PAE state": "AUTHENTICATED",
             suppPortStatus: "Authorized",
             heldPeriod: 60,
             authPeriod: 30,
             startPeriod: 30,
             maxStart: 3,
             portControl: "Auto",
             "Supplicant Backend state": "IDLE",
             "EAP state": "SUCCESS",
             reqMethod: 0,
             methodState: "NONE",
             decision: "COND_SUCC",
             ClientTimeout: 60
           }

    assert Messages.decode_resp(:PMKSA, """
           Index / AA / PMKID / expiration (in seconds) / opportunistic
           1 / 02:00:01:02:03:04 / 000102030405060708090a0b0c0d0e0f / 41362 / 0
           2 / 02:00:01:33:55:77 / 928389281928383b34afb34ba4212345 / 362 / 1
           """) ==
             String.strip("""
             Index / AA / PMKID / expiration (in seconds) / opportunistic
             1 / 02:00:01:02:03:04 / 000102030405060708090a0b0c0d0e0f / 41362 / 0
             2 / 02:00:01:33:55:77 / 928389281928383b34afb34ba4212345 / 362 / 1
             """)

    assert Messages.decode_resp({:BSS, 10}, """
           bssid=00:09:5b:95:e0:4e
           freq=2412
           beacon_int=0
           capabilities=0x0011
           qual=51
           noise=161
           level=212
           tsf=0000000000000000
           ie=000b6a6b6d2070726976617465010180dd180050f20101000050f20401000050f20401000050f2020000
           ssid=jkm private
           """) == %{
             bssid: "00:09:5b:95:e0:4e",
             freq: 2412,
             beacon_int: 0,
             capabilities: 0x0011,
             qual: 51,
             noise: 161,
             level: 212,
             tsf: 0_000_000_000_000_000,
             ie:
               "000b6a6b6d2070726976617465010180dd180050f20101000050f20401000050f20401000050f2020000",
             ssid: "jkm private"
           }

    assert Messages.decode_resp({:BSS, 100}, "\n") == nil

    assert Messages.decode_resp(:INTERFACES, "wlan0\neth0\n") == [
             "wlan0",
             "eth0"
           ]

    assert Messages.decode_resp(:ADD_NETWORK, "0") == 0

    assert Messages.decode_resp({:SET_NETWORK, 0, :ssid, "MySSID"}, "FAIL") ==
             :FAIL

    assert Messages.decode_resp({:SET_NETWORK, 0, :ssid, "MySSID"}, "OK") == :ok

    assert Messages.decode_resp({:GET_NETWORK, 0, :ssid}, "\"MySSID\"") ==
             "MySSID"
  end

  test "interactive" do
    assert Messages.decode_notif("CTRL-REQ-IDENTITY-1-Human readable text") ==
             {:"CTRL-REQ-IDENTITY", 1, "Human readable text"}

    assert Messages.decode_notif("CTRL-REQ-PASSWORD-1-Human readable text") ==
             {:"CTRL-REQ-PASSWORD", 1, "Human readable text"}

    assert Messages.decode_notif("CTRL-REQ-NEW_PASSWORD-1-Human readable text") ==
             {:"CTRL-REQ-NEW_PASSWORD", 1, "Human readable text"}

    assert Messages.decode_notif("CTRL-REQ-PIN-1-Human readable text") ==
             {:"CTRL-REQ-PIN", 1, "Human readable text"}

    assert Messages.decode_notif("CTRL-REQ-OTP-1-Human readable text") ==
             {:"CTRL-REQ-OTP", 1, "Human readable text"}

    assert Messages.decode_notif("CTRL-REQ-PASSPHRASE-1-Human readable text") ==
             {:"CTRL-REQ-PASSPHRASE", 1, "Human readable text"}
  end

  test "ctrl-event" do
    assert Messages.decode_notif(
             "CTRL-EVENT-CONNECTED - Connection to ca:21:59:2b:d2:a9 completed [id=1 id_str=]"
           ) ==
             {:"CTRL-EVENT-CONNECTED", "ca:21:59:2b:d2:a9", :completed,
              %{id: 1}}

    assert Messages.decode_notif(
             "CTRL-EVENT-DISCONNECTED bssid=ca:21:59:2b:d2:a9 reason=0 locally_generated=1"
           ) ==
             {:"CTRL-EVENT-DISCONNECTED", "ca:21:59:2b:d2:a9",
              %{reason: 0, locally_generated: 1}}

    assert Messages.decode_notif("CTRL-EVENT-TERMINATING") ==
             :"CTRL-EVENT-TERMINATING"

    assert Messages.decode_notif(
             "CTRL-EVENT-SSID-TEMP-DISABLED id=1 ssid=\"FarmbotConnect\" auth_failures=1 duration=10 reason=CONN_FAILED"
           ) ==
             {:"CTRL-EVENT-SSID-TEMP-DISABLED",
              %{
                id: 1,
                ssid: "FarmbotConnect",
                auth_failures: 1,
                duration: 10,
                reason: "CONN_FAILED"
              }}

    assert Messages.decode_notif("CTRL-EVENT-PASSWORD-CHANGED") ==
             :"CTRL-EVENT-PASSWORD-CHANGED"

    assert Messages.decode_notif("CTRL-EVENT-EAP-NOTIFICATION") ==
             :"CTRL-EVENT-EAP-NOTIFICATION"

    assert Messages.decode_notif("CTRL-EVENT-EAP-STARTED") ==
             :"CTRL-EVENT-EAP-STARTED"

    assert Messages.decode_notif("CTRL-EVENT-EAP-SUCCESS") ==
             :"CTRL-EVENT-EAP-SUCCESS"

    eap_notif = """
    CTRL-EVENT-EAP-PEER-CERT depth=0 subject='/CN=redacted.local' cert=2a93f2000ca300d06096056c6f63616c31143012060a0a47c86745000047265796e312a302806035504031321456e746572c64011916091308205743082045ca0030201013060a099226899320200110002707269736520526f6f7420434120666f72207265796e2e6c6f63616c301e170d3138303330323135323531315a170d3139303330323135323531315a3020311e301c060355040313156e70732d7374616666312e7265796e2e6c6f63616c30820122300d06092a864886f70d01010105000382010f003082010a0282010100a8b610fdced6989e72f4b45f2c7c18d0a6e9efe494faed1a106076eef430ac64a43533cfacf5c052607d33c84aa714fed3350828ad0db3df86566033a12dd19c8c3740f70abad5604cd851fea23f7b46badba151c0166b8f33d4abc6c921209f759f3ff0a0eeb48b96487f3e5b5f37ce9f2c73788b5877bf9b2720e75736257aaaa7032178edf0f4604fe476b29dbdab27944121078357ea8e7f8d6a0f28748cb49a78ce28c139ffbeb067696f25a455ca5562e0ccf744d1b4e1e9a3240094d26d5c4980eccb44bef50d84aab25090926ddacc0e8f0fbc60fbf9e25eb0cf394812f089adac4f53a5551527f1b698c21827bfdaca022748ca8287425f55f228cb0203010001a382027530820271301d06092b060104018237140204101e0e004d0061006300680069006e0065301d0603551d25041630140608864886f70d01010505003059311530f22c6499226892b0601050507030206082b06010505070301300e0603551d0f0101ff0404030205a0301d0603551d0e041604144123c436c86a7e24dd63a787cf28118d6eb6b364301f0603551d2304183016801499f022b1dca093df17ff465941fcf54ce8c82c7f3081e10603551d1f0481d93081d63081d3a081d0a081cd8681ca6c6461703a2f2f2f434e3d456e7465727072697365253230526f6f742532304341253230666f722532307265796e2e6c6f63616c2c434e3d63612c434e3d4344502c434e3d5075626c69632532304b657925323053657276696365732c434e3d53657276696365732c434e3d436f6e66696775726174696f6e2c44433d7265796e2c44433d6c6f63616c3f63657274696669636174655265766f636174696f6e4c6973743f626173653f6f626a656374436c6173733d63524c446973747269627574696f6e506f696e743081da06082b060105050701010481cd3081ca3081c706082b060105050730028681ba6c6461703a2f2f2f434e3d456e7465727072697365253230526f6f742532304341253230666f722532307265796e2e6c6f63616c2c434e3d4149412c434e3d5075626c69632532304b65792532305365727
    """

    assert Messages.decode_notif(eap_notif) ==
             {:"CTRL-EVENT-EAP-PEER-CERT",
              %{
                depth: 0,
                subject: "/CN=redacted.local",
                cert:
                  "2a93f2000ca300d06096056c6f63616c31143012060a0a47c86745000047265796e312a302806035504031321456e746572c64011916091308205743082045ca0030201013060a099226899320200110002707269736520526f6f7420434120666f72207265796e2e6c6f63616c301e170d3138303330323135323531315a170d3139303330323135323531315a3020311e301c060355040313156e70732d7374616666312e7265796e2e6c6f63616c30820122300d06092a864886f70d01010105000382010f003082010a0282010100a8b610fdced6989e72f4b45f2c7c18d0a6e9efe494faed1a106076eef430ac64a43533cfacf5c052607d33c84aa714fed3350828ad0db3df86566033a12dd19c8c3740f70abad5604cd851fea23f7b46badba151c0166b8f33d4abc6c921209f759f3ff0a0eeb48b96487f3e5b5f37ce9f2c73788b5877bf9b2720e75736257aaaa7032178edf0f4604fe476b29dbdab27944121078357ea8e7f8d6a0f28748cb49a78ce28c139ffbeb067696f25a455ca5562e0ccf744d1b4e1e9a3240094d26d5c4980eccb44bef50d84aab25090926ddacc0e8f0fbc60fbf9e25eb0cf394812f089adac4f53a5551527f1b698c21827bfdaca022748ca8287425f55f228cb0203010001a382027530820271301d06092b060104018237140204101e0e004d0061006300680069006e0065301d0603551d25041630140608864886f70d01010505003059311530f22c6499226892b0601050507030206082b06010505070301300e0603551d0f0101ff0404030205a0301d0603551d0e041604144123c436c86a7e24dd63a787cf28118d6eb6b364301f0603551d2304183016801499f022b1dca093df17ff465941fcf54ce8c82c7f3081e10603551d1f0481d93081d63081d3a081d0a081cd8681ca6c6461703a2f2f2f434e3d456e7465727072697365253230526f6f742532304341253230666f722532307265796e2e6c6f63616c2c434e3d63612c434e3d4344502c434e3d5075626c69632532304b657925323053657276696365732c434e3d53657276696365732c434e3d436f6e66696775726174696f6e2c44433d7265796e2c44433d6c6f63616c3f63657274696669636174655265766f636174696f6e4c6973743f626173653f6f626a656374436c6173733d63524c446973747269627574696f6e506f696e743081da06082b060105050701010481cd3081ca3081c706082b060105050730028681ba6c6461703a2f2f2f434e3d456e7465727072697365253230526f6f742532304341253230666f722532307265796e2e6c6f63616c2c434e3d4149412c434e3d5075626c69632532304b65792532305365727"
              }}

    assert Messages.decode_notif(
             "CTRL-EVENT-EAP-PEER-CERT depth=0 subject='/CN=staff.redacted.local' hash=a05eb2dd610feb5c77e910eb2af6b14a28fa62e6f0ca15af371a0f95b65f4f0e"
           ) == {
             :"CTRL-EVENT-EAP-PEER-CERT",
             %{
               depth: 0,
               subject: "/CN=staff.redacted.local",
               hash:
                 "a05eb2dd610feb5c77e910eb2af6b14a28fa62e6f0ca15af371a0f95b65f4f0e"
             }
           }

    assert Messages.decode_notif(
             "CTRL-EVENT-EAP-STATUS status='completion' parameter='failure'"
           ) == {
             :"CTRL-EVENT-EAP-STATUS",
             %{status: "completion", parameter: "failure"}
           }

    assert Messages.decode_notif(
             "CTRL-EVENT-EAP-STATUS status='started' parameter=''"
           ) == {
             :"CTRL-EVENT-EAP-STATUS",
             %{status: "started", parameter: ""}
           }

    assert Messages.decode_notif(
             "CTRL-EVENT-EAP-STATUS status='accept proposed method' parameter='PEAP'"
           ) == {
             :"CTRL-EVENT-EAP-STATUS",
             %{status: "accept proposed method", parameter: "PEAP"}
           }

    assert Messages.decode_notif(
             "CTRL-EVENT-EAP-FAILURE EAP authentication failed"
           ) == {
             :"CTRL-EVENT-EAP-FAILURE",
             "EAP authentication failed"
           }

    assert Messages.decode_notif(
             "CTRL-EVENT-EAP-METHOD EAP vendor 0 method 25 (PEAP) selected"
           ) == {
             :"CTRL-EVENT-EAP-METHOD",
             "EAP vendor 0 method 25 (PEAP) selected"
           }

    assert(
      Messages.decode_notif("CTRL-EVENT-EAP-PROPOSED-METHOD vendor=0 method=25") ==
        {
          :"CTRL-EVENT-EAP-PROPOSED-METHOD",
          %{vendor: 0, method: 25}
        }
    )

    assert Messages.decode_notif("CTRL-EVENT-SCAN-RESULTS") ==
             :"CTRL-EVENT-SCAN-RESULTS"

    assert Messages.decode_notif("CTRL-EVENT-BSS-ADDED 34 00:11:22:33:44:55") ==
             {:"CTRL-EVENT-BSS-ADDED", 34, "00:11:22:33:44:55"}

    assert Messages.decode_notif("CTRL-EVENT-BSS-REMOVED 34 00:11:22:33:44:55") ==
             {:"CTRL-EVENT-BSS-REMOVED", 34, "00:11:22:33:44:55"}

    assert Messages.decode_notif("WPS-OVERLAP-DETECTED") ==
             :"WPS-OVERLAP-DETECTED"

    assert Messages.decode_notif("WPS-AP-AVAILABLE-PBC") ==
             :"WPS-AP-AVAILABLE-PBC"

    assert Messages.decode_notif("WPS-AP-AVAILABLE-PIN") ==
             :"WPS-AP-AVAILABLE-PIN"

    assert Messages.decode_notif("WPS-AP-AVAILABLE") == :"WPS-AP-AVAILABLE"
    assert Messages.decode_notif("WPS-CRED-RECEIVED") == :"WPS-CRED-RECEIVED"
    assert Messages.decode_notif("WPS-M2D") == :"WPS-M2D"
    assert Messages.decode_notif("WPS-FAIL") == :"WPS-FAIL"
    assert Messages.decode_notif("WPS-SUCCESS") == :"WPS-SUCCESS"
    assert Messages.decode_notif("WPS-TIMEOUT") == :"WPS-TIMEOUT"

    # assert Messages.decode_notif("WPS-ENROLLEE-SEEN 02:00:00:00:01:00\n572cf82f-c957-5653-9b16-b5cfb298abf1 1-0050F204-1 0x80 4 1\n[Wireless Client]") ==
    #                                      {:'WPS-ENROLLEE-SEEN', "02:00:00:00:01:00", "572cf82f-c957-5653-9b16-b5cfb298abf1", "1-0050F204-1", 0x80, 4, 1, "[Wireless Client]"}

    # assert Messages.decode_notif("WPS-ER-AP-ADD 87654321-9abc-def0-1234-56789abc0002 02:11:22:33:44:55\npri_dev_type=6-0050F204-1 wps_state=1 |Very friendly name|Company|\nLong description of the model|WAP|http://w1.fi/|http://w1.fi/hostapd/") ==
    #                                     {:'WPS-ER-AP-ADD', "87654321-9abc-def0-1234-56789abc0002", "02:11:22:33:44:55", "pri_dev_type=6-0050F204-1 wps_state=1", "Very friendly name", "Company", "Long description of the model", "WAP",  "http://w1.fi/", "http://w1.fi/hostapd/"}

    # assert Messages.decode_notif("WPS-ER-AP-REMOVE 87654321-9abc-def0-1234-56789abc0002") ==
    #                                      {:'WPS-ER-AP-ADD', "87654321-9abc-def0-1234-56789abc0002"}

    # WPS-ER-ENROLLEE-ADD 2b7093f1-d6fb-5108-adbb-bea66bb87333
    # 02:66:a0:ee:17:27 M1=1 config_methods=0x14d dev_passwd_id=0
    # pri_dev_type=1-0050F204-1
    # |Wireless Client|Company|cmodel|123|12345|

    # WPS-ER-ENROLLEE-REMOVE 2b7093f1-d6fb-5108-adbb-bea66bb87333
    # 02:66:a0:ee:17:27

    # WPS-PIN-NEEDED 5a02a5fa-9199-5e7c-bc46-e183d3cb32f7 02:2a:c4:18:5b:f3
    # [Wireless Client|Company|cmodel|123|12345|1-0050F204-1]

    assert Messages.decode_notif("WPS-NEW-AP-SETTINGS") ==
             :"WPS-NEW-AP-SETTINGS"

    assert Messages.decode_notif("WPS-REG-SUCCESS") == :"WPS-REG-SUCCESS"

    assert Messages.decode_notif("WPS-AP-SETUP-LOCKED") ==
             :"WPS-AP-SETUP-LOCKED"

    assert Messages.decode_notif("AP-STA-CONNECTED 02:2a:c4:18:5b:f3") ==
             {:"AP-STA-CONNECTED", "02:2a:c4:18:5b:f3"}

    assert Messages.decode_notif("AP-STA-DISCONNECTED 02:2a:c4:18:5b:f3") ==
             {:"AP-STA-DISCONNECTED", "02:2a:c4:18:5b:f3"}

    # P2P-DEVICE-FOUND 02:b5:64:63:30:63 p2p_dev_addr=02:b5:64:63:30:63
    # pri_dev_type=1-0050f204-1 name='Wireless Client' config_methods=0x84
    # dev_capab=0x21 group_capab=0x0

    # P2P-GO-NEG-REQUEST 02:40:61:c2:f3:b7 dev_passwd_id=4
    # P2P-GO-NEG-SUCCESS
    # P2P-GO-NEG-FAILURE
    # P2P-GROUP-FORMATION-SUCCESS
    # P2P-GROUP-FORMATION-FAILURE
    # P2P-GROUP-STARTED
    # P2P-GROUP-STARTED wlan0-p2p-0 GO ssid="DIRECT-3F Testing"
    # passphrase="12345678" go_dev_addr=02:40:61:c2:f3:b7 [PERSISTENT]
    # P2P-GROUP-REMOVED wlan0-p2p-0 GO
    # P2P-PROV-DISC-SHOW-PIN 02:40:61:c2:f3:b7 12345670
    # p2p_dev_addr=02:40:61:c2:f3:b7 pri_dev_type=1-0050F204-1 name='Test'
    # config_methods=0x188 dev_capab=0x21 group_capab=0x0
    # P2P-PROV-DISC-ENTER-PIN 02:40:61:c2:f3:b7 p2p_dev_addr=02:40:61:c2:f3:b7
    # pri_dev_type=1-0050F204-1 name='Test' config_methods=0x188
    # dev_capab=0x21 group_capab=0x0
    # P2P-PROV-DISC-PBC-REQ 02:40:61:c2:f3:b7 p2p_dev_addr=02:40:61:c2:f3:b7
    # pri_dev_type=1-0050F204-1 name='Test' config_methods=0x188
    # dev_capab=0x21 group_capab=0x0
    # P2P-PROV-DISC-PBC-RESP 02:40:61:c2:f3:b7
    # P2P-SERV-DISC-REQ 2412 02:40:61:c2:f3:b7 0 0 02000001
    # P2P-SERV-DISC-RESP 02:40:61:c2:f3:b7 0 0300000101
    # P2P-INVITATION-RECEIVED sa=02:40:61:c2:f3:b7 persistent=0
    # P2P-INVITATION-RESULT status=1

    assert Messages.decode_notif(
             "Trying to associate with 58:6d:8f:8d:c8:92 (SSID='LKC Tech HQ' freq=2412 MHz)"
           ) ==
             {:INFO,
              "Trying to associate with 58:6d:8f:8d:c8:92 (SSID='LKC Tech HQ' freq=2412 MHz)"}
  end
end
