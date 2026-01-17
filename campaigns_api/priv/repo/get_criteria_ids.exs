# Helper script to get all criteria IDs
# Run with: mix run get_criteria_ids.exs

alias CampaignsApi.Criteria

IO.puts("\n=== Available Criteria IDs ===\n")

Criteria.list_criteria()
|> Enum.sort_by(& &1.name)
|> Enum.each(fn criterion ->
  status = if criterion.status == "active", do: "✓", else: "✗"
  IO.puts("#{status} #{String.pad_trailing(criterion.name, 30)} | ID: #{criterion.id}")
end)

IO.puts("\n=== Copy-Paste Ready Format ===\n")

Criteria.list_criteria()
|> Enum.sort_by(& &1.name)
|> Enum.each(fn criterion ->
  IO.puts(~s|# #{criterion.name}
"criterion_id": "#{criterion.id}"|)
  IO.puts("")
end)

IO.puts("=== End ===\n")
