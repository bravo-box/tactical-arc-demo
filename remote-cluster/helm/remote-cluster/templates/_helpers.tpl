{{- define "remote-cluster.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "remote-cluster.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "remote-cluster.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "remote-cluster.labels" -}}
app.kubernetes.io/name: {{ include "remote-cluster.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
{{- end -}}

{{- define "remote-cluster.image" -}}
{{- $registry := .Values.imageRegistry | trimSuffix "/" -}}
{{- $image := printf "%s:%s" .Values.edgeAgent.image.repository .Values.edgeAgent.image.tag -}}
{{- if $registry -}}
{{- printf "%s/%s" $registry $image -}}
{{- else -}}
{{- $image -}}
{{- end -}}
{{- end -}}
