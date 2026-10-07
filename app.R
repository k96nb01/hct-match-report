#
# HCT donor match report: Shiny front end.
#
# Type the recipient's and the donor's high-resolution typing (two alleles per
# locus; leave the second blank for a homozygote), or paste a GL String for
# either, or fill in one of the synthetic example pairs. Choose the match
# direction (and, for bidirectional, the scope), then press "Generate report"
# to download the PDF.
#
# The optional labels are printed on the report; they are never sent to the
# matching API or the DPB1 TCE service. Only the typing is sent to the matching
# API (and the DPB1 alleles to the DPB1 TCE service).
#

library(shiny)
library(tidyverse)
source("R/report.R")
source("R/hct_match.R")  # dpb1_tce_docs_url, for the link
source("R/examples.R")

# The loci on the form, in report order.
form_loci <- c("A", "B", "C", "DRB1", "DQA1", "DQB1", "DPA1", "DPB1")

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
    textAreaInput(str_c(side, "_gl"), "Or paste a GL String (used instead of the boxes)",
                  rows = 3, placeholder = "HLA-A*02:01+HLA-A*24:02^HLA-B*07:02+...")
  )
}

ui <- fluidPage(
  titlePanel("HCT Donor Match Report"),
  # .noWS keeps Shiny from putting a space between a link and the full stop
  # after it.
  p("Enter two-field (or longer) allele names, without the locus prefix. ",
    "Mismatches are counted after reduction to P groups by the ",
    a("immunogenetr matching API", href = "https://api.immunogenetr.org/__docs__/",
      target = "_blank", .noWS = "after"),
    ". DPB1 permissiveness comes from the ",
    a("IPD-IMGT/HLA DPB1 T-cell epitope matching service", href = dpb1_tce_docs_url,
      target = "_blank", .noWS = "after"),
    "."),
  p(strong("For research use only."),
    " Any clinical use requires independent validation according to local regulations."),

  # Top to bottom: the two typings; the options, with the button that uses
  # them; the examples.
  fluidRow(
    column(6, wellPanel(h4("Recipient"), typing_inputs("recipient"))),
    column(6, wellPanel(h4("Donor"), typing_inputs("donor")))
  ),
  fluidRow(
    column(12, wellPanel(
      h4("Matching options"),
      radioButtons("direction", "Direction", inline = TRUE, selected = "bidirectional",
                   choices = c("Bidirectional" = "bidirectional",
                               "GvH (graft versus host)" = "GvH",
                               "HvG (host versus graft)" = "HvG")),
      # Scope only affects a bidirectional match grade, so it is shown only then.
      conditionalPanel(
        "input.direction == 'bidirectional'",
        radioButtons("scope", "Scope of the bidirectional match grade", selected = "locus",
                     choices = c("Locus: the worse direction at each locus, added up" = "locus",
                                 "Genotype: the worse of the GvH and HvG totals" = "genotype"))
      ),
      downloadButton("report", "Generate report", class = "btn-primary"),
      helpText("The PDF may take up to a minute.")
    ))
  ),
  fluidRow(
    column(12, wellPanel(
      h4("Try an example"),
      selectInput("example", NULL, width = "100%",
                  choices = set_names(seq_along(example_pairs), map_chr(example_pairs, "name"))),
      helpText(textOutput("example_description")),
      actionButton("fill_example", "Fill in this example"),
      helpText("Synthetic typings. They fill both GL String boxes above.")
    ))
  )
)

server <- function(input, output, session) {

  output$example_description <- renderText(example_pairs[[as.integer(input$example)]]$description)

  # Put the chosen example in the GL String boxes, and clear the allele boxes
  # so the form shows only what will be used.
  observeEvent(input$fill_example, {
    pair <- example_pairs[[as.integer(input$example)]]
    for (side in c("recipient", "donor")) {
      updateTextAreaInput(session, str_c(side, "_gl"), value = pair[[side]])
      for (l in form_loci) for (i in 1:2) updateTextInput(session, str_c(side, "_", l, "_", i), value = "")
    }
  })

  # One person's typing from the form: the pasted GL String if there is one,
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
            donor_label     = input$donor_label,
            direction       = input$direction,
            scope           = input$scope
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
