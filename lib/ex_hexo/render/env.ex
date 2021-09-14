defmodule ExHexo.Render.Env do
  import ExHexo.Render.Helper, warn: false
  alias ExHexo.{Post, Page, Paginater}, warn: false

  def env(file), do: %{__ENV__ | file: file, line: 1}
end
