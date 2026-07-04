@{
    # WHY exclude PSAvoidUsingWriteHost: every .ps1 file in this project is a
    # CLI tool or a git hook whose entire purpose is printing human-readable,
    # colored status to a console for a person or Claude to read — not a
    # library function returning pipeline data. Write-Host is the correct
    # choice here: Write-Output would pollute return values, Write-Information
    # isn't visible by default. This is a deliberate, project-wide exception,
    # not a general suppression of the rule's intent.
    ExcludeRules = @('PSAvoidUsingWriteHost')
}
