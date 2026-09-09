{{- define "payroll.name" -}}
payroll
{{- end }}

{{- define "payroll.fullname" -}}
{{ .Release.Name }}
{{- end }}

{{- define "payroll.labels" -}}
app.kubernetes.io/name: {{ include "payroll.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
