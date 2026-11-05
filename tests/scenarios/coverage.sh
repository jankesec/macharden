#!/bin/zsh
echo "\n\033[1m[Scenarios] Coverage ratchet and blind run\033[0m"

# Print the first tab-separated field of every non-comment, non-empty line of a list file.
sc_load_list() {
    local file="$1" line
    while IFS= read -r line; do
        [[ -z "$line" || "$line" == \#* ]] && continue
        print -r -- "${line%%$'\t'*}"
    done < "$file"
}

typeset -a sc_gaps sc_allow sc_registered sc_complete sc_blind_pass
sc_gaps=("${(@f)$(sc_load_list "$SC_LIB_DIR/known_gaps.txt")}");               sc_gaps=(${sc_gaps:#})
sc_allow=("${(@f)$(sc_load_list "$SC_LIB_DIR/blind_pass_allowlist.txt")}");   sc_allow=(${sc_allow:#})
sc_registered=("${REG_IDS[@]}")
sc_complete=("${(@u)SC_SEAMS_COMPLETE}")

# 1. Every registered check is either seam-complete or a known gap, never both.
sc_bad=""
for sc_id in "${sc_registered[@]}"; do
    sc_in_complete=$(( ${sc_complete[(Ie)$sc_id]} > 0 ))
    sc_in_gaps=$(( ${sc_gaps[(Ie)$sc_id]} > 0 ))
    if (( sc_in_complete && sc_in_gaps )); then
        sc_bad+=" $sc_id(both)"
    elif (( ! sc_in_complete && ! sc_in_gaps )); then
        sc_bad+=" $sc_id(neither)"
    fi
done
sc_assert "$([[ -z "$sc_bad" ]] && echo 0 || echo 1)" "every registered check is scenario-covered or a known gap" "$sc_bad"

# 2. The lists contain no stale IDs.
sc_bad=""
for sc_id in "${sc_gaps[@]}" "${sc_allow[@]}" "${sc_complete[@]}"; do
    (( ${sc_registered[(Ie)$sc_id]} )) || sc_bad+=" $sc_id"
done
sc_assert "$([[ -z "$sc_bad" ]] && echo 0 || echo 1)" "known_gaps, the allowlist and seams_complete only name registered checks" "$sc_bad"

# 3. Every covered check has at least three scenarios (secure, insecure, no evidence).
sc_bad=""
for sc_id in "${sc_complete[@]}"; do
    (( ${SC_COUNT[$sc_id]:-0} >= 3 )) || sc_bad+=" $sc_id(${SC_COUNT[$sc_id]:-0})"
done
sc_assert "$([[ -z "$sc_bad" ]] && echo 0 || echo 1)" "every covered check has at least three scenarios" "$sc_bad"

# 4. Blind run: with no commands, an empty root and an empty HOME, only the allowlisted checks may report PASS.
sc_blind_pass=()
for sc_id in "${sc_complete[@]}"; do
    scenario_begin "$sc_id" "blind run"
    sc_line=$(sc_exec "$sc_id")
    [[ "${sc_line%%$'\t'*}" == "PASS" ]] && sc_blind_pass+=("$sc_id")
    rm -rf "$SC_DIR"
done
sc_bad=""
for sc_id in "${sc_blind_pass[@]}"; do
    (( ${sc_allow[(Ie)$sc_id]} )) || sc_bad+=" $sc_id"
done
sc_assert "$([[ -z "$sc_bad" ]] && echo 0 || echo 1)" "no check reports PASS without evidence unless it is allowlisted" "reported PASS blind:$sc_bad"
sc_bad=""
for sc_id in "${sc_allow[@]}"; do
    (( ${sc_blind_pass[(Ie)$sc_id]} )) || sc_bad+=" $sc_id"
done
sc_assert "$([[ -z "$sc_bad" ]] && echo 0 || echo 1)" "every allowlisted check still reports PASS blind (the list stays honest)" "no longer PASS blind:$sc_bad"
