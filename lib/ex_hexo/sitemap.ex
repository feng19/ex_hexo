defmodule ExHexo.Sitemap do
  @code """
  defmodule ExHexo.Sitemaps do
  use Sitemap, files_path: "public/", public_path: "/"

  def generate do
    create compress: false, host: unquote(host) do
      for {path, attrs} <- unquote(pages) do
        add path, attrs
      end
    end
  end
  end

  ExHexo.Sitemaps.generate()
  """

  def generate(host, pages) do
    pages =
      Enum.map(pages, fn {path, page} ->
        lastmod = page.last_mod |> NaiveDateTime.from_erl!() |> NaiveDateTime.to_iso8601()
        {path <> "/index.html", [priority: page.priority, changefreq: page.change_freq, lastmod: lastmod]}
      end)

    {result, _} = Code.eval_string(@code, host: host, pages: pages)
    :code.delete(ExHexo.Sitemaps)
    :code.purge(ExHexo.Sitemaps)
    result
  end
end
