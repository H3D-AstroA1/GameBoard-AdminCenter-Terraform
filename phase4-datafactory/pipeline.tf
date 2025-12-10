# Create Copy Activity Pipeline
resource "azurerm_data_factory_pipeline" "copy_logs_pipeline" {
  provider = azurerm.admincenter

  name            = "Copy-GameBoard-Logs"
  data_factory_id = data.azurerm_data_factory.logs_adf.id

  variables = {
    SourceWorkspace = var.gameboard_workspace_name
    DestContainer   = "gameboard-logs"
    RunDate         = "@{formatDateTime(utcNow(), 'yyyy-MM-dd')}"
  }

  activities_json = jsonencode([
    {
      name = "Copy-Logs-Activity"
      type = "Copy"
      
      inputs = [
        {
          referenceName = azurerm_data_factory_dataset_parquet.admincenter_sink_optimized.name
          type          = "DatasetReference"
        }
      ]

      outputs = [
        {
          referenceName = azurerm_data_factory_dataset_parquet.admincenter_sink_optimized.name
          type          = "DatasetReference"
        }
      ]

      typeProperties = {
        source = {
          type = "AzureLogAnalyticsSource"
          query = "union withsource=TableName * | where TimeGenerated > ago(24h)"
        }

        sink = {
          type = "ParquetSink"
          storeSettings = {
            type = "AzureBlobFSWriteSettings"
          }
          formatSettings = {
            type = "ParquetWriteSettings"
          }
        }

        translator = {
          type = "TabularTranslator"
          mappings = []
          # Auto-detect schema
          schemaMapping = []
        }

        enableStaging = false
        parallelCopies = 4
        cloudDataMovementUnits = 4
        
        # Retry configuration
        retry = 3
        retryWait = 30
      }

      policy = {
        timeout = "0.02:00:00"
        retry   = 3
        delay   = 5
      }

      depends_on = [
        {
          activity = "Validate-Connection"
          dependencyConditions = ["Succeeded"]
        }
      ]
    },
    
    {
      name = "Validate-Connection"
      type = "Validation"
      
      typeProperties = {
        dataset = {
          referenceName = azurerm_data_factory_dataset_parquet.admincenter_sink_optimized.name
          type          = "DatasetReference"
        }
        timeout = "0.00:05:00"
        sleep   = 10
      }
    }
  ])

  depends_on = [
    azurerm_data_factory_dataset_parquet.admincenter_sink_optimized,
    azurerm_data_factory_linked_service_azure_log_analytics.gameboard_source_mi
  ]
}

# Create Schedule Trigger for automatic daily execution
resource "azurerm_data_factory_trigger_schedule" "daily_copy_trigger" {
  provider = azurerm.admincenter

  name            = "Daily-Log-Copy-Trigger"
  data_factory_id = data.azurerm_data_factory.logs_adf.id
  pipeline_name   = azurerm_data_factory_pipeline.copy_logs_pipeline.name

  activated = true

  frequency = "Day"
  interval  = 1
  
  # Start at 2:00 AM daily (adjust as needed)
  schedule {
    hours   = [2]
    minutes = [0]
  }

  # Optional: Add time zone
  start_time = timestamp()
  # end_time = "2099-12-31T23:59:59Z" # Keep running indefinitely

  depends_on = [azurerm_data_factory_pipeline.copy_logs_pipeline]
}

# Output trigger information
output "trigger_name" {
  description = "Name of the schedule trigger"
  value       = azurerm_data_factory_trigger_schedule.daily_copy_trigger.name
  sensitive   = false
}

output "trigger_frequency" {
  description = "Frequency of trigger execution"
  value       = "${azurerm_data_factory_trigger_schedule.daily_copy_trigger.interval} ${azurerm_data_factory_trigger_schedule.daily_copy_trigger.frequency}"
  sensitive   = false
}

output "trigger_schedule" {
  description = "Schedule details"
  value       = "Daily at 2:00 AM"
  sensitive   = false
}
