# Sourced by run_tests.sh and run_self_tests.sh, from the project root, with
# $godot set to the Godot binary.
#
# Without an up-to-date import cache, class_names are missing (a fresh checkout
# or worktree has no cache; a new class_name, e.g. from a pull or rebase, isn't
# in it yet), and tests using them would hang until their timeout. Import the
# project first when the cache is missing or a script is newer than it.
ensure_imported() {
	local cache=.godot/global_script_class_cache.cfg
	local reason=""
	if [[ ! -f $cache ]]; then
		reason="No import cache found"
	elif [[ -n $(find . -path ./.godot -prune -o -name '*.gd' -newer "$cache" -print -quit) ]]; then
		reason="Scripts changed since the last import"
	else
		# A moved or renamed script keeps its old mtime (git mv, mv), so the check
		# above misses it; catch it by the cache listing a path that's now gone.
		local script
		while IFS= read -r script; do
			if [[ ! -f ${script#res://} ]]; then
				reason="Scripts moved since the last import"
				break
			fi
		done < <(sed -n 's/^"path": "\(res:\/\/[^"]*\)"$/\1/p' "$cache")
	fi
	if [[ -n $reason ]]; then
		echo "$reason, importing the project..."
		if ! "$godot" --headless --import >/dev/null 2>&1 || [[ ! -f $cache ]]; then
			echo "Import failed; run '$godot --headless --import' to see why."
			return 1
		fi
		# Godot leaves the cache alone when no class changed; mark it current so
		# the next run doesn't import again.
		touch "$cache"
	fi
}
