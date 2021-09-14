defmodule ExHexo.Paginater do
  @moduledoc false

  def paginate([], key, page, page_size) do
    assigns =
      Keyword.merge(page.assigns,
        page_size: page_size,
        total_entries: 0,
        total_pages: 1,
        page_number: 1
      )
      |> Keyword.put(key, [])

    %{page | assigns: assigns}
  end

  def paginate(entries, key, page, page_size) do
    total_entries = length(entries)
    total_pages = ceil(total_entries / page_size)

    assigns =
      Keyword.merge(page.assigns,
        page_size: page_size,
        total_entries: total_entries,
        total_pages: total_pages
      )

    Stream.chunk_every(entries, page_size)
    |> Enum.map_reduce(1, fn page_entries, page_number ->
      assigns = Keyword.merge(assigns, [{:page_number, page_number}, {key, page_entries}])
      {{page_number, %{page | assigns: assigns}}, page_number + 1}
    end)
    |> elem(0)
    |> case do
      [{1, page}] -> page
      list -> list
    end
  end
end
