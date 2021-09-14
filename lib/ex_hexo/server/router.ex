defmodule ExHexo.Server.Router do
  @moduledoc false
  use Plug.Router

  plug :match
  plug :dispatch

  get "/" do
    conn
    |> put_resp_content_type("text/html")
    |> read_file_and_send(200, "public/index.html")
  end

  get "/live_reload/frame" do
    body = """
    <html><body>
    <script>
    socket = new WebSocket("ws://" + location.host + "/live_reload/socket")
    socket.addEventListener("message", (event) => {
      window["top"].location.reload();
    })
    </script>
    </body></html>
    """

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, body)
    |> halt()
  end

  get "/index.html" do
    conn
    |> put_resp_content_type("text/html")
    |> read_file_and_send(200, "public/index.html")
  end

  get "/404.html" do
    conn
    |> put_resp_content_type("text/html")
    |> read_file_and_send(404, "public/404.html")
  end

  get "/*path/" do
    filename = "public/#{Path.join(path)}/index.html"

    if File.exists?(filename) do
      conn
      |> put_resp_content_type("text/html")
      |> read_file_and_send(200, filename)
    else
      # not_found(conn)
      conn
    end
  end

  plug Plug.Static, at: "/", from: "public"

  match _ do
    not_found(conn)
  end

  defp not_found(conn) do
    url = "/404.html"
    html = Plug.HTML.html_escape(url)
    body = "<html><body>You are being <a href=\"#{html}\">redirected</a>.</body></html>"

    conn
    |> put_resp_header("location", url)
    |> put_resp_content_type("text/html")
    |> send_resp(302, body)
    |> halt()
  end

  defp read_file_and_send(conn, status, filename) do
    body = filename |> File.read!() |> inject_reloader()

    send_resp(conn, status, body)
    |> halt()
  end

  defp inject_reloader(body) do
    [page | rest] = String.split(body, "</body>")

    [
      page,
      ~s(<iframe src="/live_reload/frame", hidden, height="0", width="0"></iframe>),
      "</body>" | rest
    ]
  end
end
