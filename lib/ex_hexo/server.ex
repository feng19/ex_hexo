defmodule ExHexo.Server do
  require Logger
  alias ExHexo.Server.{Router, Watcher}

  def serve(config_file, port) do
    {:ok, _} = Registry.start_link(keys: :duplicate, name: ExHexo.Registry)

    Watcher.start_link(config_file)

    Plug.Cowboy.http(Router, [],
      port: port,
      dispatch: [
        {:_,
         [
           {"/live_reload/socket", ExHexo.Server.Socket, []},
           {:_, Plug.Cowboy.Handler, {Router, []}}
         ]}
      ]
    )

    Logger.info("start visit your site on: http://127.0.0.1:#{port}/")

    # watch files and regen when some file changed
    Watcher.io_read(config_file)
  end
end
