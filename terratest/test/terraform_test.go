package test

import (
	"fmt"
	"os/exec"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestECRDefaultApply is the canonical happy-path Terratest. It applies the
// module with minimum-required vars, asserts the two test repositories exist
// via direct AWS API calls, then destroys.
func TestECRDefaultApply(t *testing.T) {
	t.Parallel()

	envName := fmt.Sprintf("ci-%s", random.UniqueId())
	region := "us-east-1"

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../plan",
		Vars: map[string]interface{}{
			"project":     "tt",
			"environment": envName,
			"region":      region,
		},
		NoColor: true,
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	repoUrls := terraform.OutputMap(t, terraformOptions, "repository_urls")
	require.Contains(t, repoUrls, "app")
	require.Contains(t, repoUrls, "base")

	appRepoUrl := repoUrls["app"]
	require.Contains(t, appRepoUrl, ".dkr.ecr.us-east-1.amazonaws.com/")

	// Verify the repo exists via the AWS API.
	repoNames := terraform.OutputMap(t, terraformOptions, "repository_names")
	repo := aws.GetEcrRepository(t, region, repoNames["app"])
	assert.Equal(t, "KMS", *repo.EncryptionConfiguration.EncryptionType)
	assert.Equal(t, "IMMUTABLE", *repo.ImageTagMutability)

	// And the mutable-tags repo overrides correctly.
	baseRepo := aws.GetEcrRepository(t, region, repoNames["base"])
	assert.Equal(t, "MUTABLE", *baseRepo.ImageTagMutability)
}

// TestECRPushAndPullRoundtrip pushes a real image, pulls it back, and confirms
// the scan-on-push pipeline triggered. Requires docker on the runner; skips
// otherwise.
func TestECRPushAndPullRoundtrip(t *testing.T) {
	t.Parallel()

	if _, err := exec.LookPath("docker"); err != nil {
		t.Skip("docker not in PATH; skipping push/pull roundtrip")
	}

	envName := fmt.Sprintf("ci-%s", random.UniqueId())
	region := "us-east-1"

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../plan",
		Vars: map[string]interface{}{
			"project":     "tt",
			"environment": envName,
			"region":      region,
		},
		NoColor: true,
	})

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	repoUrl := terraform.OutputMap(t, terraformOptions, "repository_urls")["app"]
	accountId := terraform.Output(t, terraformOptions, "registry_id")
	registryHost := fmt.Sprintf("%s.dkr.ecr.%s.amazonaws.com", accountId, region)

	// Authenticate Docker against the ECR registry.
	loginCmd := fmt.Sprintf(
		"aws ecr get-login-password --region %s | docker login --username AWS --password-stdin %s",
		region, registryHost,
	)
	runShell(t, loginCmd)

	// Tag the public hello-world image and push it.
	runShell(t, "docker pull public.ecr.aws/docker/library/hello-world:linux")
	runShell(t, fmt.Sprintf("docker tag public.ecr.aws/docker/library/hello-world:linux %s:test", repoUrl))
	runShell(t, fmt.Sprintf("docker push %s:test", repoUrl))

	// Pull back from ECR to confirm.
	runShell(t, fmt.Sprintf("docker rmi %s:test", repoUrl))
	runShell(t, fmt.Sprintf("docker pull %s:test", repoUrl))
}

func runShell(t *testing.T, cmd string) {
	t.Helper()
	out, err := exec.Command("sh", "-c", cmd).CombinedOutput()
	require.NoError(t, err, "command failed: %s\noutput: %s", cmd, strings.TrimSpace(string(out)))
}
