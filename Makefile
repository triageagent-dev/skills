# tria-bundle packages the skills and the map of which Tria is offered
# (tria/map.yaml and tria/<skill>.md) as one OCI artifact the core pulls through
# its skills cell (chart value skills.ref). An empty base, one layer, plain
# files; version.txt carries VERSION.
VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo dev)

.PHONY: tria-check
tria-check: ## Check that every skill the map names exists and has its text for Tria
	@fail=0; for s in $$(sed -n 's/^  - name: *//p' tria/map.yaml); do \
		ls plugins/*/skills/$$s/SKILL.md >/dev/null 2>&1 || { echo "map names $$s, which no plugin holds" >&2; fail=1; }; \
		test -s tria/$$s.md || { echo "no tria/$$s.md" >&2; fail=1; }; \
	done; \
	for f in tria/*.md; do s=$$(basename $$f .md); grep -q "^  - name: $$s$$" tria/map.yaml || { echo "tria/$$s.md is not in the map" >&2; fail=1; }; done; \
	exit $$fail

.PHONY: tria-bundle
tria-bundle: tria-check ## Push the bundle: make tria-bundle SKILLS_ARTIFACT=<registry/repo/skills-bundle>
	@command -v crane >/dev/null 2>&1 || { echo "crane not found: go install github.com/google/go-containerregistry/cmd/crane@latest" >&2; exit 1; }
	@test -n "$(SKILLS_ARTIFACT)" || { echo "SKILLS_ARTIFACT is required, e.g. ghcr.io/ORG/skills-bundle" >&2; exit 1; }
	@tmpdir=$$(mktemp -d); mkdir "$$tmpdir/tree"; \
	cp -R plugins tria "$$tmpdir/tree/"; \
	find "$$tmpdir/tree" -name '.*' -delete; \
	printf '%s\n' "$(VERSION)" > "$$tmpdir/tree/version.txt"; \
	(cd "$$tmpdir/tree" && COPYFILE_DISABLE=1 tar -cf ../skills.tar .); \
	crane append --oci-empty-base -f "$$tmpdir/skills.tar" -t "$(SKILLS_ARTIFACT):$(VERSION)" >/dev/null; \
	rm -rf "$$tmpdir"; \
	echo "$(SKILLS_ARTIFACT)@$$(crane digest $(SKILLS_ARTIFACT):$(VERSION))"
