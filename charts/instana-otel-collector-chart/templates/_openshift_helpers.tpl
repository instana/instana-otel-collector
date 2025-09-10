{{/* OpenShift Helper Functions */}}

{{/*
Determine if we're running on OpenShift
*/}}
{{- define "instana-otel-collector.isOpenShift" -}}
{{- $openshift := dict "enabled" false "autoDetect" true -}}
{{- if hasKey .Values "openshift" -}}
  {{- $openshift = .Values.openshift -}}
{{- end -}}
{{- if $openshift.enabled -}}
  {{- true -}}
{{- else if $openshift.autoDetect -}}
  {{- /* Try to detect OpenShift by checking for OpenShift-specific APIs */ -}}
  {{- $isOpenShift := false -}}
  {{- /* Use safe lookup with try/catch to avoid errors on non-OpenShift clusters */ -}}
  {{- if (.Capabilities.APIVersions.Has "route.openshift.io/v1") -}}
    {{- $isOpenShift = true -}}
  {{- else if (.Capabilities.APIVersions.Has "apps.openshift.io/v1") -}}
    {{- $isOpenShift = true -}}
  {{- else if (.Capabilities.APIVersions.Has "security.openshift.io/v1") -}}
    {{- $isOpenShift = true -}}
  {{- end -}}
  {{- $isOpenShift -}}
{{- else -}}
  {{- false -}}
{{- end -}}
{{- end -}}
