defmodule App.Http do
  use Plug.Router

  plug :match
  plug :dispatch

  get "/health" do
    send_resp(conn, 200, "ok")
  end

  match _ do
    send_resp(conn, 404, "not found")
  end
end
