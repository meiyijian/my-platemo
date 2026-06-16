param(
    [string]$TablePath = "D:\MyCode\research-agent-suite\data\experiments\sample_results.csv",
    [string]$OutputPath = "D:\MyCode\research-agent-suite\data\reports\experiment_report.md"
)

$Project = "D:\MyCode\research-agent-suite"
Set-Location $Project

python -m research_agent_suite.cli analyze --table $TablePath --output $OutputPath
