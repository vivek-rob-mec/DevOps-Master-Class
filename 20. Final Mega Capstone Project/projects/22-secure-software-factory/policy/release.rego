package release
import rego.v1
default allow := false
allow if {
 input.signature.verified == true
 input.provenance.slsa_build_level >= 2
 input.sbom.format in {"spdx-json", "cyclonedx-json"}
 input.scan.fixable_critical == 0
 input.image_ref == input.signature.subject
}
deny contains message if { not input.signature.verified; message := "signature is not verified" }
deny contains message if { input.scan.fixable_critical > 0; message := "fixable critical vulnerabilities remain" }
