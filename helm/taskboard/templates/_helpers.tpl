{{/*
Expand the name of the chart.
*/}}
{{- define "taskboard.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Fully qualified app name.
*/}}
{{- define "taskboard.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Component names.
*/}}
{{- define "taskboard.apiName" -}}
{{- printf "%s-api" (include "taskboard.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "taskboard.webName" -}}
{{- printf "%s-web" (include "taskboard.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Chart label.
*/}}
{{- define "taskboard.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels.
*/}}
{{- define "taskboard.labels" -}}
helm.sh/chart: {{ include "taskboard.chart" . }}
{{ include "taskboard.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Web labels (same as common labels, but with the web selector labels so no
key is ever emitted twice).
*/}}
{{- define "taskboard.webLabels" -}}
helm.sh/chart: {{ include "taskboard.chart" . }}
{{ include "taskboard.webSelectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
API selector labels.
*/}}
{{- define "taskboard.selectorLabels" -}}
app.kubernetes.io/name: {{ include "taskboard.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app: taskboard-api
{{- end }}

{{/*
Web selector labels.
*/}}
{{- define "taskboard.webSelectorLabels" -}}
app.kubernetes.io/name: {{ include "taskboard.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app: taskboard-web
{{- end }}
