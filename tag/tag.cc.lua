{{- /*
	This command manages the tag system.

	Usage: 

	`-tag add <name> <value>`
	`-tag del <name>`
	`-tag addalias <name> <...aliases>`
	`-tag delalias <name> <alias>`
	`-tag list`
	`-tag info <name>`
	`-<tag>` (i.e say you have tag with name `foobar`, `-foobar` would view that tag)

	Recommended trigger: StartsWith trigger with trigger `-`.
*/ -}}

{{ $isCmd := reFind "^tags? +" .StrippedMsg }}
{{ $safeName := `^[^\|_%]{1,25}$` }}

{{ define "getTag" }}
	{{ $tagName := lower .Name }}
	{{ $tag := 0 }}
	{{ $entries := dbTopEntries (printf "tg.%%|%s|%%" $tagName) 1 0 }}
	{{ if len $entries }} {{ $tag = index $entries 0 }} {{ end }}
	{{ .Set "Tag" $tag }}
{{ end }}

{{ if $isCmd }}
	{{ $cmd := "" }}
	{{ $args := cslice }}
	{{ if gt (len .CmdArgs) 1 }} {{ $cmd = index .CmdArgs 1 }} {{ end }}
	{{ if gt (len .CmdArgs ) 2 }}  {{ $args = slice .CmdArgs 2 }} {{ end }}

	{{ if and (eq $cmd "add") (ge (len $args) 2) }}
		{{ $tagName := index $args 0 | lower }}
		{{ $tagContent := slice $args 1 | joinStr " " }}
		{{ if reFind $safeName $tagName }}
			{{ $data := sdict "Name" $tagName }}
			{{ template "getTag" $data }}
			{{ if not $data.Tag }}
				{{ dbSet 0 (printf "tg.|%s|" $tagName) $tagContent }}
				Successfully added a tag with the name `{{ $tagName }}`.
			{{ else }}
				That tag already exists.
			{{ end }}
		{{ else }}
			Tag names must not contain the `|`, `_`, or `%` character and be under 25 characters!
		{{ end }}

	{{ else if and (eq $cmd "del") (len $args) }}
		{{ $toDelete := joinStr " " $args }}
		{{ $data := sdict "Name" $toDelete }}
		{{ template "getTag" $data }}
		{{ with $data.Tag }}
			{{ dbDelByID .UserID .ID }}
			Successfully deleted the tag `{{ index (split (slice .Key 4 (sub (len .Key) 1)) "|") 0 }}`!
		{{ else }}
			Sorry, that tag does not exist.
		{{ end }}

	{{ else if and (eq $cmd "info") (len $args) }}
		{{ $tagName := joinStr " " $args }}
		{{ $data := sdict "Name" $tagName }}
		{{ template "getTag" $data }}
		{{ with $data.Tag }}
			{{ $aliases := split (slice .Key 4 (sub (len .Key) 1)) "|" }}
			{{ $list := "" }}
			{{ if ge (len $aliases) 2 }}
				{{- range $k, $ := slice $aliases 1 -}}
					{{ if $k }}
						{{ $list = joinStr "" $list ", `" . "`" }}
					{{ else if . }}
						{{ $list = printf "`%s`" . }}
					{{ end }}
				{{ end }}
			{{ end }}
			{{ sendMessage nil (cembed
				"title" "❯ Tag Info"
				"color" 14232643
				"fields" (cslice
					(sdict "name" "❯ Name" "value" (index $aliases 0))
					(sdict "name" "❯ Aliases" "value" (or $list "n/a"))
					(sdict "name" "❯ Created At" "value" (.CreatedAt.Format "Jan 02, 2006 3:04 PM"))
				)
			) }}
		{{ else }}
			That tag does not exist. Try again?
		{{ end }}

	{{ else if and (eq $cmd "edit") (ge (len $args) 2) }}
		{{ $tagName := index $args 0 }}
		{{ $tagContent := slice $args 1 | joinStr " " }}
		{{ if reFind $safeName $tagName }}
			{{ $data := sdict "Name" $tagName }}
			{{ template "getTag" $data }}
			{{ with $data.Tag }}
				{{ dbSet 0 .Key $tagContent }}
				Successfully edited the content of the tag `{{ $tagName }}`.
			{{ else }}
				Sorry, that tag does not exist!
			{{ end }}
		{{ else }}
			That tag does not exist!
		{{ end }}

	{{ else if and (eq $cmd "addalias") (ge (len $args) 2) }}
		{{ $tagName := index $args 0 }}
		{{ $aliases := slice $args 1 }}
		{{ $valid := true }}
		{{ $key := printf "tg.|%s|" $tagName }}
		{{- range $k, $ := $aliases -}}
			{{ if not (reFind $safeName .) }}
				{{ $valid = false }}
			{{ else if $k }}
				{{ $key = joinStr "" $key "|" (lower .) }}
			{{ else }}
				{{ $key = joinStr "" $key (lower .) }}
			{{ end }}
		{{ end }}
		{{ if and (reFind $safeName $tagName) $valid }}
			{{ $data := sdict "Name" $tagName }}
			{{ template "getTag" $data }}
			{{ with $data.Tag }}
				{{ dbDelByID .UserID .ID }}
				{{ dbSet 0 (joinStr "" $key "|") .Value }}
				Successfully added {{ len $aliases }} aliases to the tag `{{ $tagName }}`!
			{{ else }}
				Sorry, that tag does not exist.
			{{ end }}
		{{ else }}
			Sorry, some aliases provided were not valid! Try again.
		{{ end }}

	{{ else if and (eq $cmd "delalias") (ge (len $args) 2) }}
		{{ $tagName := index $args 0 }}
		{{ $toRemove := slice $args 1 | joinStr " " | lower }}
		{{ $data := sdict "Name" $tagName }}
		{{ template "getTag" $data }}
		{{ with $data.Tag }}
			{{ $aliases := split (slice .Key 4 (sub (len .Key) 1)) "|" }}
			{{ $tagName := printf "tg." }}
			{{ if eq (len $aliases) 1 }}
				Sorry, you cannot remove an alias from a tag with only 1 alias.
			{{ else }}
				{{ range $aliases }}
					{{ if ne $toRemove . }}
						{{ $tagName = joinStr "" $tagName "|" . }}
					{{ end }}
				{{ end }}
				{{ $tagName = joinStr "" $tagName "|" }}
				{{ dbDelByID .UserID .ID }}
				{{ dbSet 0 $tagName .Value }}
				Successfully removed alias!
			{{ end }}
		{{ else }}
			That tag does not exist.
		{{ end }}

	{{ else if eq $cmd "list" }}
		{{ $page := 1 }}
		{{ if eq (len $args) 1 }} {{ with reFind `^\d+$` (index $args 0) }} {{ $page = toInt . }} {{ end }} {{ end }}
		{{ $skip := mult (sub $page 1) 10 }}
		{{ $tags := dbTopEntries "tg.|%|" 10 $skip }}
		{{ if not (len $tags) }}
			There were no tags on that page!
		{{ else }}
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
			{{ $id := sendMessageRetID nil (cembed
				"title" "❯ Tags"
				"color" 14232643
				"description" $display
				"footer" (sdict "text" (joinStr "" "Page " $page))
			) }}
			{{ addMessageReactions nil $id "◀️" "▶️" }}
		{{ end }}
	{{ end }}

{{ else }}
	{{ $tagName := reFind $safeName .StrippedMsg }}
	{{ if $tagName }}
		{{ $data := sdict "Name" $tagName }}
		{{ template "getTag" $data }}
		{{ with $data.Tag }}
			{{ sendMessage nil .Value }}
		{{ end }}
	{{ end }}
{{ end }}