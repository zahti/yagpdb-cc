{{/*
	This command manages tag list pagination.

	Recommended trigger: Reaction trigger on REACTION ADDED only.
*/}}

{{ $action := .Reaction.Emoji.Name }}
{{ $validEmojis := cslice "▶️" "◀️" }}
{{ $isValid := false }}
{{ $page := 0 }} {{/* The current page */}}
{{ with and (eq .ReactionMessage.Author.ID 204255221017214977) .ReactionMessage.Embeds }}
	{{ $embed := index . 0 }}
	{{ if and (eq $embed.Title "❯ Tags") $embed.Footer }}
		{{ $page = reFind `\d+` $embed.Footer.Text }}
		{{ $isValid = true }}
	{{ end }}
{{ end }}
{{ if and (in $validEmojis $action) $isValid $page }}
	{{ if eq $action "▶️" }} {{ $page = add $page 1 }}
	{{ else }} {{ $page = sub $page 1 }} {{ end }}
	{{ if ge $page 1 }}
		{{ $skip := mult (sub $page 1) 10 }}
		{{ $tags := dbTopEntries "tg.|%|" 10 $skip }}
		{{ if (len $tags) }}
			{{ $number := $skip }}
			{{ $display := "" }}
			{{- range $k, $ := $tags -}}
				{{ $tagName := index (split (slice .Key 4 (sub (len .Key) 1)) "|") 0 }}
				{{ if $k }}
					{{ $display = joinStr "" $display ", `" $tagName "`" }}
				{{ else }}
					{{ $display = printf "`%s`" $tagName }}
				{{ end }}
			{{ end }}
			{{ editMessage nil .ReactionMessage.ID (cembed
				"title" "❯ Tags"
				"color" 14232643
				"description" $display
				"footer" (sdict "text" (joinStr "" "Page " $page))
			) }}
		{{ end }}
	{{ end }}
{{ end }}
