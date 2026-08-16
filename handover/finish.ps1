# finish.ps1 — 任务收尾：总结写日志 + 刷新状态快照（一键交接）
# 用法：powershell -File finish.ps1 -Task "一句话总结" [-Detail "详情" -Files "文件1,文件2" -Issues "问题" -Pending "待办"]
# 兼容 PS 5.1 / 7；只追加/只刷标记区，不删除任何内容
param(
  [Parameter(Mandatory = $true)][string]$Task,
  [string]$Detail = '',
  [string]$Files  = '',
  [string]$Issues = '',
  [string]$Pending = ''
)

$ErrorActionPreference = 'Continue'
$me = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Output '==> [1/2] 写交接日志'
& (Join-Path $me 'log-entry.ps1') -Task $Task -Detail $Detail -Files $Files -Issues $Issues -Pending $Pending

Write-Output '==> [2/2] 刷新状态快照'
& (Join-Path $me 'update-guide.ps1')

Write-Output ''
Write-Output '交接收尾完成：日志已记录、快照已刷新。'
Write-Output '下一位 AI 接手时运行 brief.ps1 即可快速了解情况。'
