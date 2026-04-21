# CV Repo — Claude Guide

## What this repo is

Ihsan's academic CV, rendered as a PDF via Quarto + Typst (awesomecv-typst extension).

**Never edit `bib/cv.bib` by hand** — Zotero owns it via Better BibTeX auto-export.

## Repo layout

| Path | Purpose |
|---|---|
| `cv.qmd` | Main document — YAML header + section assembly |
| `_quarto.yml` | Project config |
| `_extensions/awesomecv/` | Patched awesomecv-typst extension (Quarto 1.6 compat) |
| `data/education.yml` | Education entries |
| `data/positions.yml` | Employment / research positions |
| `data/teaching.yml` | Teaching (instructor, TA, workshops) |
| `data/awards.yml` | Fellowships and awards |
| `data/affiliations.yml` | Professional memberships |
| `data/software.yml` | Open-source software projects |
| `bib/cv.bib` | Zotero auto-export — **do not edit by hand** |
| `R/render_bib.R` | ReadBib + filter + print helpers |
| `csl/cv-style.csl` | Chicago author-date, no URL/DOI |
| `.github/workflows/render-cv.yml` | CI: render → GitHub Pages |
| `archive/` | Old .docx — for reference during migration |

## YAML data format

Each `data/*.yml` file uses this shape (all fields optional):

```yaml
entry_key:
  title: "Title or role"
  location: "Institution, City"
  date: "2021 – Present"
  description: "One-line detail"
  details:
    - Bullet point one
    - Bullet point two
```

## Bib categorization (keywords in Zotero)

| CV Section | Entry type | Keywords |
|---|---|---|
| Peer-Reviewed Articles | `@article` | `peer-reviewed` |
| Book Chapters | `@incollection` / `@inbook` | `book-chapter` |
| Working Papers | `@unpublished` | `working-paper` |
| Conference Presentations | `@misc` | `talk` |
| Excluded | any | `exclude` |

Tag rules live in `R/render_bib.R` — easy to change.

## How to render locally

```bash
quarto render cv.qmd
# PDF is written to _output/cv.pdf
open _output/cv.pdf
```

Requires: R with RefManageR (`install.packages("RefManageR")`), Quarto 1.6+.

## Common update tasks

### Add a new position / award / course

Edit the relevant `data/*.yml` file. Copy an existing entry as a template.

### Add a publication or talk

Add to Zotero with correct entry type and keyword tag. Better BibTeX rewrites
`bib/cv.bib` automatically. Commit `bib/cv.bib`, re-render.

### Change section order

Reorder the `#` headings in `cv.qmd`.

### Change accent color

Edit `style.color-accent` in the YAML header of `cv.qmd`. Use a 6-digit hex string **without** the `#` (e.g., `"4B2E83"`).

## Design notes

- Extension patched to work with Quarto 1.6 (`_extensions/awesomecv/_extension.yml` has `>=1.6.0`)
- `set document()` moved before `#show:` in `_extensions/awesomecv/typst-show.typ` for Typst 0.11 compatibility
- Heading first-3-chars color split removed (not compatible with Typst 0.11); full heading uses accent color
