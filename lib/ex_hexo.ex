defmodule ExHexo do
  @moduledoc """
  Documentation for `ExHexo`.
  """

  @parse_opts [
    switches: [
      dev: :boolean,
      build: :boolean
    ],
    aliases: [d: :dev, b: :build]
  ]

  # todo as a mix task
  # hexo.gen
  # hexo.server
  # hexo.build
  def main(args) do
    {parsed, argv, _errors} = OptionParser.parse(args, @parse_opts)

    config_file =
      case argv do
        [file | _] -> file
        _ -> "config.exs"
      end

    with true <- File.exists?(config_file),
         {config, _} <- Code.eval_file(config_file) do
      config
      |> ExHexo.GenHtml.run()
      |> put_config()

      cond do
        Keyword.get(parsed, :dev, false) ->
          dev(config_file)

        Keyword.get(parsed, :build, false) ->
          build()

        true ->
          :ignore
      end
    else
      _ -> IO.puts("!!! config file not exists !!!")
    end
  end

  def dev(config_file) do
    ExHexo.Server.serve(config_file, 8080)
  end

  def build do
    {_, 0} = System.cmd("zip", ["-qr", "../site", "."], cd: "public")
    IO.puts("build site.zip")
  end

  def config do
    :persistent_term.get(:ex_hexo_config)
  end

  def put_config(config) do
    :persistent_term.put(:ex_hexo_config, config)
  end
end
