{{- define "bunzina.name" -}}
bunzina
{{- end -}}

{{- define "bunzina.labels" -}}
app.kubernetes.io/name: bunzina
app.kubernetes.io/part-of: bunzina
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "bunzina.selectorLabels" -}}
app.kubernetes.io/name: bunzina
{{- end -}}