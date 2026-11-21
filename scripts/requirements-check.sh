#!/bin/sh
# Reads a requirements brief in the knackpack-requirements/1 format and says
# whether the work it describes may start:
#
#   sh scripts/requirements-check.sh <brief>
#
# The brief is any file, such as REQUIREMENTS.md, REQUIREMENTS-<name>.md or
# .knackpack/<task>/REQUIREMENTS.md. It prints exactly one line and changes
# nothing:
#
#   ready                  exit 0: valid, and no question says Blocking: yes
#   blocked Q-02 Q-05      exit 1: these questions say Blocking: yes
#   invalid: <reason>      exit 2: the brief breaks the format; the reason
#                          names the line and the ID where there is one
#   none                   exit 3: no marker line, so an older format
#   error: <reason>        exit 4: not one argument, or not a readable
#                          regular file
#
# Beyond the structure that finds them, the format checks two things: every
# open question ends its bullet line with Blocking: yes or Blocking: no, and
# every requirement has an Acceptance: line. Lines in code fences count for
# nothing. A second reader written elsewhere must give the same result and
# blocking IDs on every input, so this one adds no rule beyond
# docs/requirements-format.md, which holds the format's rules, and reads the
# text in one pass.
#
# NUL bytes become \001 before awk, since awks differ on NUL and the format
# treats it as a byte that matches nothing. Lines are tested with ~ or with
# anchored patterns, match() runs only on a line whose shape is already known,
# and nothing uses sub(), gsub() or a loop over substr(), so a very long line
# costs time in proportion to its length under every awk.

export LC_ALL=C
unset CDPATH
error() {
	printf 'error: %s\n' "$1"
	exit 4
}

[ "$#" -eq 1 ] || error "give exactly one argument, the path of the requirements brief to read"
[ -f "$1" ] || error "the path given doesn't exist or isn't a regular file"
[ -r "$1" ] || error "the file given can't be read"

# The awk program. It holds no single quote, so it can sit in one here. A
# problem tied to a line is kept only when it's the first one reached; on a
# heading line, the heading's own problem comes before the end of the body it
# closes, the order the format lists them in.
# shellcheck disable=SC2016 # the $ signs are awk's
prog='
function problem(n, why) {
	if (!bad) { bad = 1; reason = "line " n ": " why }
}
function end_body(n) {
	if (open != "" && !accepted) problem(n, open " has no Acceptance: line")
	open = ""
}
{
	l = $0
	if (substr(l, length(l), 1) == "\r") l = substr(l, 1, length(l) - 1)
	# A UTF-8 byte-order mark at the very start of the text goes, once.
	if (NR == 1 && substr(l, 1, 3) == "\357\273\277") l = substr(l, 4)

	# Code fences: at most 3 leading spaces or tabs, then 3 or more of one
	# character; closed by a run of it at least as long, then only blanks.
	if (fence != "") {
		if (fence == "`") { if (l ~ /^[ \t]?[ \t]?[ \t]?`+[ \t]*$/ && match(l, /`+/) && RLENGTH >= fence_len) fence = "" }
		else if (l ~ /^[ \t]?[ \t]?[ \t]?~+[ \t]*$/ && match(l, /~+/) && RLENGTH >= fence_len) fence = ""
		next
	}
	if (l ~ /^[ \t]?[ \t]?[ \t]?```/) { match(l, /`+/); fence = "`"; fence_len = RLENGTH; next }
	if (l ~ /^[ \t]?[ \t]?[ \t]?~~~/) { match(l, /~+/); fence = "~"; fence_len = RLENGTH; next }

	if (l ~ /^[ \t]*knackpack-requirements\/1[ \t]*$/) {
		if (marker) problem(NR, "a second knackpack-requirements/1 marker line; the first is on line " marker)
		else marker = NR
		next
	}

	level = 0
	if (l ~ /^#/) {
		match(l, /^#+/)
		c = substr(l, RLENGTH + 1, 1)
		if (RLENGTH <= 6 && (c == "" || c == " " || c == "\t")) level = RLENGTH
	}
	if (level >= 1 && level <= 4) {
		section = 0
		if (level <= 3) {
			if (l ~ /^### Requirements and acceptance criteria[ \t]*$/) {
				section = 1
				if (req_line) problem(NR, "a second \"### Requirements and acceptance criteria\" heading; the first is on line " req_line)
			} else if (l ~ /^### Open questions and risks[ \t]*$/) {
				section = 2
				if (q_line) problem(NR, "a second \"### Open questions and risks\" heading; the first is on line " q_line)
			}
		} else if (in_req) {
			if (l ~ /^#### [A-Z][A-Z0-9]*-[0-9][0-9]?[0-9]?[0-9]?: .*[^ \t]/) {
				id = substr(l, 6, index(l, ":") - 6)
				if (id in req_ids) problem(NR, id " is a second requirement with that ID; the first is on line " req_ids[id])
				new_req = id
			} else {
				problem(NR, "a level-4 heading in the Requirements section that is not \"#### <ID>: <text>\", with an ID such as REQ-01")
				new_req = ""
			}
		}
		end_body(NR)
		if (level <= 3) {
			in_req = (section == 1)
			in_q = (section == 2)
			if (section == 1 && !req_line) req_line = NR
			if (section == 2 && !q_line) q_line = NR
		} else if (in_req && new_req != "") {
			if (!(new_req in req_ids)) req_ids[new_req] = NR
			open = new_req
			accepted = 0
			reqs++
		}
		next
	}

	if (open != "" && l ~ /^Acceptance:.*[^ \t]/) accepted = 1

	if (in_q && l ~ /^- Q-[0-9]/) {
		if (l !~ /^- Q-[0-9][0-9]?[0-9]?[0-9]?: .*[^ \t]/) {
			problem(NR, "a \"- Q-\" bullet that is not a question, \"- Q-<n>: <text>\" with 1 to 4 digits")
			next
		}
		id = substr(l, 3, index(l, ":") - 3)
		if (id in q_ids) problem(NR, id " is a second question with that ID; the first is on line " q_ids[id])
		else q_ids[id] = NR
		i = index(l, "Blocking:")
		if (i == 0) problem(NR, id " has no Blocking: marker; end its line with Blocking: yes or Blocking: no")
		else if (index(substr(l, i + 9), "Blocking:")) problem(NR, id " has Blocking: more than once; its line needs exactly one")
		else if (l ~ /Blocking: yes[ \t]*$/) blocked = blocked " " id
		else if (l !~ /Blocking: no[ \t]*$/) problem(NR, id " does not end with Blocking: yes or Blocking: no, in lowercase")
	}
}
END {
	end_body(NR)
	if (!marker) print "none"
	else if (bad) print "invalid: " reason
	else if (!req_line) print "invalid: no \"### Requirements and acceptance criteria\" section"
	else if (!q_line) print "invalid: no \"### Open questions and risks\" section"
	else if (!reqs) print "invalid: line " req_line ": the Requirements section holds no \"#### <ID>: <text>\" requirement"
	else if (blocked != "") print "blocked" blocked
	else print "ready"
}'

# When tr can't read the whole file, the line it adds on fd 3 makes the
# output two lines, which is reported as an error below, rather than awk's
# verdict on part of the text.
out=$({ { tr '\000' '\001' <"$1" || echo unread >&3; } 2>/dev/null | awk "$prog"; } 3>&1)

case $out in
*'
'*) error "couldn't read the whole file" ;;
ready) code=0 ;;
'blocked Q-'*) code=1 ;;
'invalid: '*) code=2 ;;
none) code=3 ;;
*) error "couldn't read the file" ;;
esac
printf '%s\n' "$out"
exit "$code"
