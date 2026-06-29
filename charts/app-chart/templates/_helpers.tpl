{{/*
Labels padrão. Recebe um dict: { name, root } onde root é o contexto raiz ($).
*/}}
{{- define "app-chart.labels" -}}
app.kubernetes.io/name: {{ .name }}
app.kubernetes.io/part-of: {{ .root.Chart.Name }}
app.kubernetes.io/managed-by: {{ .root.Release.Service }}
helm.sh/chart: {{ .root.Chart.Name }}-{{ .root.Chart.Version }}
{{- end -}}

{{/*
Selector labels (subconjunto estável). Recebe um dict: { name }.
*/}}
{{- define "app-chart.selectorLabels" -}}
app.kubernetes.io/name: {{ .name }}
{{- end -}}
