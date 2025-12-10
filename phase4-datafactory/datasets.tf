# Create Dataset for GameBoard Log Analytics (Source)
resource "azurerm_data_factory_dataset_azure_blob" "gameboard_logs_source" {
  provider = azurerm.admincenter

  name            = "GameBoard-Logs-Dataset"
  data_factory_id = data.azurerm_data_factory.logs_adf.id
  linked_service_name = azurerm_data_factory_linked_service_azure_log_analytics.gameboard_source_mi.name

  # This dataset queries the Log Analytics workspace
  type = "AzureLogAnalytics"

  dynamic "type_properties" {
    for_each = [1]
    content {
      query = var.kusto_query != null ? var.kusto_query : "union withsource=TableName * | where TimeGenerated > ago(24h)"
    }
  }
}

# Create Dataset for AdminCenter Blob Storage (Sink)
resource "azurerm_data_factory_dataset_parquet" "admincenter_sink_dataset" {
  provider = azurerm.admincenter

  name            = "AdminCenter-Logs-Sink"
  data_factory_id = data.azurerm_data_factory.logs_adf.id
  linked_service_name = azurerm_data_factory_linked_service_azure_blob_storage.admincenter_sink.name

  # Location in blob storage
  azure_blob_fs_location {
    file_system = "gameboard-logs"
    path        = "logs"
    filename    = ""
  }

  # Optional: Additional configuration
  compression_level = "Optimal"
}

# Alternative: Parquet format with custom settings
resource "azurerm_data_factory_dataset_parquet" "admincenter_sink_optimized" {
  provider = azurerm.admincenter

  name            = "AdminCenter-Logs-Sink-Optimized"
  data_factory_id = data.azurerm_data_factory.logs_adf.id
  linked_service_name = azurerm_data_factory_linked_service_azure_blob_storage.admincenter_sink.name

  azure_blob_fs_location {
    file_system = "gameboard-logs"
    path        = "logs/${formatdate("YYYY-MM-DD", timestamp())}"
    filename    = "data.parquet"
  }

  compression_codec = "snappy"
  
  parameters = {
    container = "gameboard-logs"
    folder    = "logs"
  }

  depends_on = [azurerm_data_factory_linked_service_azure_blob_storage.admincenter_sink]
}
