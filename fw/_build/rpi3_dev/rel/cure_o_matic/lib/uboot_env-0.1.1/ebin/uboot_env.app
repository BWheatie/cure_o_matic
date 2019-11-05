{application,uboot_env,
             [{applications,[kernel,stdlib,elixir]},
              {description,"Read and write to U-Boot environment blocks\n"},
              {modules,['Elixir.Mix.Tasks.UbootEnv.Delete',
                        'Elixir.Mix.Tasks.UbootEnv.Read',
                        'Elixir.Mix.Tasks.UbootEnv.Write',
                        'Elixir.Mix.UbootEnv.Utils','Elixir.UBootEnv',
                        'Elixir.UBootEnv.Config','Elixir.UBootEnv.Tools']},
              {registered,[]},
              {vsn,"0.1.1"}]}.