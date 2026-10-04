#
# HCT donor match report: Shiny front end.
#
# Type the recipient's and the donor's high-resolution typing (two alleles per
# locus; leave the second blank for a homozygote), or paste a GL string for
# either, then press "Generate report" to download the PDF.
#
# The optional labels are printed on the report only. Only the typing is sent
# to the matching API (and the DPB1 alleles to the DPB1 TCE service).
#

library(shiny)
library(tidyverse)
source("R/report.R")

# The loci on the form, in report order.
form_loci <- c("A", "B", "C", "DRB1", "DQB1", "DPB1")

# Two allele boxes per locus for one person. Input ids are e.g. "recipient_A_1".
typing_inputs <- function(side) {
  rows <- map(form_loci, \(l) fluidRow(
    column(2, tags$label(l, style = "padding-top: 8px")),
    column(5, textInput(str_c(side, "_", l, "_1"), NULL, placeholder = "e.g. 02:01")),
    column(5, textInput(str_c(side, "_", l, "_2"), NULL))
  ))
  tagList(
    textInput(str_c(side, "_label"), "Label (printed on the report only)",
              value = str_to_title(side)),
    rows,
    textAreaInput(str_c(side, "_gl"), "Or paste a GL string (used instead of the boxes)",
                  rows = 2, placeholder = "HLA-A*02:01+HLA-A*24:02^HLA-B*07:02+...")
  )
}

ui <- fluidPage(
  titlePanel("HCT Donor Match Report"),
  p("Enter two-field (or longer) allele names, without the locus prefix. ",
    "Mismatches are counted bidirectionally after reduction to P groups by the ",
    a("immunogenetr matching API", href = "https://api.immunogenetr.org/__docs__/", target = "_blank"),
    ". DPB1 permissiveness comes from the IPD-IMGT/HLA DPB1 T-cell epitope matching service."),
  p(strong("For research use only."),
    " Any clinical use requires independent validation according to local regulations."),
  fluidRow(
    column(5, wellPanel(h4("Recipient"), typing_inputs("recipient"))),
    column(5, wellPanel(h4("Donor"), typing_inputs("donor"))),
    column(2, br(), downloadButton("report", "Generate report"),
           br(), br(), helpText("The PDF may take up to a minute."))
  )
)

server <- function(input, output, session) {

  # One person's typing from the form: the pasted GL string if there is one,
  # otherwise the allele boxes.
  form_typing <- function(side) {
    gl <- str_squish(input[[str_c(side, "_gl")]])
    if (nzchar(gl)) return(gl)
    map(set_names(form_loci), \(l) c(input[[str_c(side, "_", l, "_1")]],
                                     input[[str_c(side, "_", l, "_2")]]))
  }

  output$report <- downloadHandler(
    filename = function() str_c("hct_match_report_", format(Sys.Date(), "%Y%m%d"), ".pdf"),
    content = function(file) {
      withProgress(message = "Generating report", value = 1, {
        # Show the reason on screen if the report fails (an unreadable typing,
        # or the matching API cannot be reached), then fail the download.
        tryCatch(
          hct_match_report(
            recipient       = form_typing("recipient"),
            donor           = form_typing("donor"),
            file            = file,
            recipient_label = input$recipient_label,
            donor_label     = input$donor_label
          ),
          error = function(e) {
            showNotification(str_c("The report could not be generated: ", conditionMessage(e)),
                             type = "error", duration = NULL)
            stop(e)
          })
      })
    }
  )
}

shinyApp(ui = ui, server = server)
