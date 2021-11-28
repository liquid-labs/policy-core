generate-page() {
  local SETTINGS
  SETTINGS=$(cat <<EOF
---
title: '${TITLE}'
author: 'TODO: Author Name'
...
EOF
)

  CSS=$(cat <<'EOF'
source ./github.css # bash-rollup-no-recur
EOF
)

  echo "pandoc \
    --toc \
    --standalone \
    --from gfm \
    --to "${INTERMEDIDATE_FORMAT}" \
    \"${MD_FILE}\" \
    -o \"${BASE_OUTPUT}\""

  pandoc \
    $( [[ "${OUTPUT_FORMAT}" == 'docx' ]] || echo '--toc' ) \
    --standalone \
    --from gfm \
    --to ${INTERMEDIDATE_FORMAT} \
    --css <(echo "${CSS}") \
    --metadata-file <(echo "${SETTINGS}") \
    "${MD_FILE}" \
    -o "${BASE_OUTPUT}"

  if [[ "${OUTPUT_FORMAT}" == 'pdf' ]]; then
    # generate headers and footers as a separate document and overlay them.
    # Note, if we ever go back to a latex generator, you can use 'header-include' to configure to generate headers and
    # footers as part of the first run.

    DOC_DATA="$(pdftk "${BASE_OUTPUT}" dump_data)"
    PAGE_COUNT=$(echo "${DOC_DATA}" | grep NumberOfPages | cut -d: -f2)
    MEDIA_DIMENSIONS=$(echo "${DOC_DATA}" | grep PageMediaDimensions | head -n 1)
    XPAGE=$(echo "${MEDIA_DIMENSIONS}" | cut -d: -f2 | cut -d' ' -f 2)
    YPAGE=$(echo "${MEDIA_DIMENSIONS}" | cut -d: -f2 | cut -d' ' -f 3)
    HF_FONT_SIZE=9
    PG_NUMBER_X_OFFSET=$((${XPAGE} - 145))
    VERSION_X_OFFSET=75
    FOOTER_Y_OFFSET=35
    HEADER_Y_OFFSET=$((${YPAGE} - ${FOOTER_Y_OFFSET}))
    TITLE_X_OFFSET=$((${XPAGE} / 2 + 10))


    # TODO: make the positioning relative to the margins, with proper justification; abstract into a 'top-left', 'top-
    # centered', 'top-right', 'bottom-right', 'bottom-centered', and 'bottom-left' abstraction
    # https://www.tek-tips.com/viewthread.cfm?qid=830058
    OVERLAY_OUTPUT="${TITLE}-overlay.pdf"
    FOOTER_STRING="/Helvetica findfont \
      ${HF_FONT_SIZE} scalefont setfont \
      1 1  ${PAGE_COUNT} {      \
      /PageNo exch def          \
      ${PG_NUMBER_X_OFFSET} ${FOOTER_Y_OFFSET} moveto \
      (Page ) show              \
      PageNo 3 string cvs       \
      show                      \
      ( of ${PAGE_COUNT}) show  \
      ${VERSION_X_OFFSET} ${FOOTER_Y_OFFSET} moveto \
      ( Version: ${VERSION} ) show \
      PageNo 1 gt \
      { /Helvetica-Oblique findfont \
        ${HF_FONT_SIZE} scalefont setfont \
        ${TITLE_X_OFFSET} ${HEADER_Y_OFFSET} moveto \
        ( "${TITLE}" ) show \
        /Helvetica findfont \
        ${HF_FONT_SIZE} scalefont setfont \
      } if \
      showpage                  \
      } for"
    gs -o "${OVERLAY_OUTPUT}"       \
      -sDEVICE=pdfwrite             \
      -g${XPAGE}0x${YPAGE}0         \
      -c "${FOOTER_STRING}"

    COMBINED_FILE="${TITLE}-combined.${OUTPUT_FORMAT}"

    echo "pdftk \"${BASE_OUTPUT}\" multistamp \"${OVERLAY_OUTPUT}\" output \"${COMBINED_FILE}\""
    pdftk "${BASE_OUTPUT}" multistamp "${OVERLAY_OUTPUT}" output "${COMBINED_FILE}"
    mv "${COMBINED_FILE}" "${TITLE}.${OUTPUT_FORMAT}"
    [[ -n "${KEEP_INTERMEDIATE}" ]] || rm "${OVERLAY_OUTPUT}"
  fi
}