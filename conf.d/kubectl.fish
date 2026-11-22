# kubectl — short names for kubectl, as Fish abbreviations.
#
# kes leaves the cursor on the pod name. Zsh has it as a function taking the
# pod, since an alias cannot put an argument in the middle of a line.

if status is-interactive
    abbr --add k -- kubectl
    abbr --add kube -- kubectl
    abbr --add kes --set-cursor -- "kubectl get events -A --sort-by=.lastTimestamp --field-selector involvedObject.name=%"
end
