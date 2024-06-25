source('SCRIPTS/run_mappings_on_summary_data.R')

dashboard <-  buildStatusDashboard(
  summary_data_5,
  output_file_html = 'docs/index.html'
  )
