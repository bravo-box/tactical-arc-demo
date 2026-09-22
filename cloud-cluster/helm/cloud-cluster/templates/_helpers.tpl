{{- define "cloud-cluster.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "cloud-cluster.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "cloud-cluster.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "cloud-cluster.labels" -}}
app.kubernetes.io/name: {{ include "cloud-cluster.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
{{- end -}}

{{- define "cloud-cluster.image" -}}
{{- $registry := .Values.imageRegistry | trimSuffix "/" -}}
{{- $image := printf "%s:%s" .Values.telemetryApi.image.repository .Values.telemetryApi.image.tag -}}
{{- if $registry -}}
{{- printf "%s/%s" $registry $image -}}
{{- else -}}
{{- $image -}}
{{- end -}}
{{- end -}}
