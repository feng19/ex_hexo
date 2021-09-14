defmodule ExHexo.Server.Socket do
  @moduledoc false
  require Logger

  @behaviour :cowboy_websocket

  def reload do
    Registry.dispatch(
      ExHexo.Registry,
      :sockets,
      &Enum.each(&1, fn {pid, _} ->
        send(pid, :reload)
      end)
    )
  end

  @impl :cowboy_websocket
  def init(request, state \\ %{}) do
    {:cowboy_websocket, request, state}
  end

  @impl :cowboy_websocket
  def websocket_init(state) do
    Registry.register(ExHexo.Registry, :sockets, self())
    {:ok, state}
  end

  @impl :cowboy_websocket
  def websocket_handle(_inframe, state) do
    {:ok, state}
  end

  @impl :cowboy_websocket
  def websocket_info(:reload, state) do
    Logger.debug("Live reload!")
    {:reply, {:text, "reload"}, state}
  end
end
