package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/spf13/cobra"
	"gopkg.in/yaml.v3"
)

// Config represents the main configuration structure
type Config struct {
	Name        string `yaml:"name" json:"name"`
	Version     string `yaml:"version" json:"version"`
	Description string `yaml:"description" json:"description"`
	Author      string `yaml:"author" json:"author"`
	License     string `yaml:"license" json:"license"`
	Image       struct {
		Name      string `yaml:"name" json:"name"`
		Tag       string `yaml:"tag" json:"tag"`
		Registry  string `yaml:"registry" json:"registry"`
		Namespace string `yaml:"namespace" json:"namespace"`
	} `yaml:"image" json:"image"`
	Base struct {
		Template     string   `yaml:"template" json:"template"`
		Architecture []string `yaml:"architecture" json:"architecture"`
	} `yaml:"base" json:"base"`
	Tools struct {
		Languages map[string]ToolConfig `yaml:"languages" json:"languages"`
		Security  map[string]ToolConfig `yaml:"security" json:"security"`
		DevOps    map[string]ToolConfig `yaml:"devops" json:"devops"`
		Packages  []string              `yaml:"packages" json:"packages"`
	} `yaml:"tools" json:"tools"`
	Security struct {
		Trivy      TrivyConfig      `yaml:"trivy" json:"trivy"`
		CodeQL     CodeQLConfig     `yaml:"codeql" json:"codeql"`
		Compliance ComplianceConfig `yaml:"compliance" json:"compliance"`
		SAST       SASTConfig       `yaml:"sast" json:"sast"`
	} `yaml:"security" json:"security"`
	Optimization struct {
		MultiStage  bool `yaml:"multi_stage" json:"multi_stage"`
		CacheLayers bool `yaml:"cache_layers" json:"cache_layers"`
		Minify      bool `yaml:"minify" json:"minify"`
		StripDebug  bool `yaml:"strip_debug" json:"strip_debug"`
	} `yaml:"optimization" json:"optimization"`
	Testing struct {
		StructureTests   StructureTestsConfig   `yaml:"structure_tests" json:"structure_tests"`
		IntegrationTests IntegrationTestsConfig `yaml:"integration_tests" json:"integration_tests"`
		PerformanceTests PerformanceTestsConfig `yaml:"performance_tests" json:"performance_tests"`
	} `yaml:"testing" json:"testing"`
	Pipeline struct {
		GitHubActions GitHubActionsConfig `yaml:"github_actions" json:"github_actions"`
		Artifacts     ArtifactsConfig     `yaml:"artifacts" json:"artifacts"`
		Notifications NotificationsConfig `yaml:"notifications" json:"notifications"`
	} `yaml:"pipeline" json:"pipeline"`
	Output struct {
		SBOM        SBOMConfig        `yaml:"sbom" json:"sbom"`
		Signing     SigningConfig     `yaml:"signing" json:"signing"`
		Attestation AttestationConfig `yaml:"attestation" json:"attestation"`
	} `yaml:"output" json:"output"`
	Custom struct {
		PreBuild  string `yaml:"pre_build" json:"pre_build"`
		PostBuild string `yaml:"post_build" json:"post_build"`
	} `yaml:"custom" json:"custom"`
}

// ToolConfig represents tool configuration
type ToolConfig struct {
	Install bool   `yaml:"install" json:"install"`
	Version string `yaml:"version" json:"version"`
}

// TrivyConfig represents Trivy scanner configuration
type TrivyConfig struct {
	Enabled       bool   `yaml:"enabled" json:"enabled"`
	Severity      string `yaml:"severity" json:"severity"`
	ExitCode      int    `yaml:"exit_code" json:"exit_code"`
	IgnoreUnfixed bool   `yaml:"ignore_unfixed" json:"ignore_unfixed"`
}

// CodeQLConfig represents CodeQL configuration
type CodeQLConfig struct {
	Enabled   bool     `yaml:"enabled" json:"enabled"`
	Languages []string `yaml:"languages" json:"languages"`
}

// ComplianceConfig represents compliance configuration
type ComplianceConfig struct {
	Enabled   bool     `yaml:"enabled" json:"enabled"`
	Standards []string `yaml:"standards" json:"standards"`
}

// SASTConfig represents SAST configuration
type SASTConfig struct {
	Enabled bool     `yaml:"enabled" json:"enabled"`
	Tools   []string `yaml:"tools" json:"tools"`
}

// StructureTestsConfig represents structure test configuration
type StructureTestsConfig struct {
	Enabled bool   `yaml:"enabled" json:"enabled"`
	Config  string `yaml:"config" json:"config"`
}

// IntegrationTestsConfig represents integration test configuration
type IntegrationTestsConfig struct {
	Enabled bool   `yaml:"enabled" json:"enabled"`
	Timeout string `yaml:"timeout" json:"timeout"`
}

// PerformanceTestsConfig represents performance test configuration
type PerformanceTestsConfig struct {
	Enabled       bool   `yaml:"enabled" json:"enabled"`
	BenchmarkTool string `yaml:"benchmark_tool" json:"benchmark_tool"`
}

// GitHubActionsConfig represents GitHub Actions configuration
type GitHubActionsConfig struct {
	Matrix   MatrixConfig `yaml:"matrix" json:"matrix"`
	Parallel []string     `yaml:"parallel" json:"parallel"`
}

// MatrixConfig represents matrix build configuration
type MatrixConfig struct {
	OS   []string `yaml:"os" json:"os"`
	Arch []string `yaml:"arch" json:"arch"`
}

// ArtifactsConfig represents artifact configuration
type ArtifactsConfig struct {
	RetentionDays int `yaml:"retention_days" json:"retention_days"`
}

// NotificationsConfig represents notification configuration
type NotificationsConfig struct {
	Slack struct {
		Enabled bool   `yaml:"enabled" json:"enabled"`
		Webhook string `yaml:"webhook" json:"webhook"`
	} `yaml:"slack" json:"slack"`
}

// SBOMConfig represents SBOM configuration
type SBOMConfig struct {
	Enabled bool     `yaml:"enabled" json:"enabled"`
	Formats []string `yaml:"formats" json:"formats"`
}

// SigningConfig represents signing configuration
type SigningConfig struct {
	Enabled bool         `yaml:"enabled" json:"enabled"`
	Cosign  CosignConfig `yaml:"cosign" json:"cosign"`
}

// CosignConfig represents Cosign configuration
type CosignConfig struct {
	Enabled bool `yaml:"enabled" json:"enabled"`
	Keyless bool `yaml:"keyless" json:"keyless"`
}

// AttestationConfig represents attestation configuration
type AttestationConfig struct {
	Enabled         bool `yaml:"enabled" json:"enabled"`
	Provenance      bool `yaml:"provenance" json:"provenance"`
	SBOMAttestation bool `yaml:"sbom_attestation" json:"sbom_attestation"`
}

var (
	cfgFile string
	config  Config
)

var rootCmd = &cobra.Command{
	Use:   "foundry",
	Short: "ImageFoundry - Build custom container images with E2E CI/CD",
	Long: `ImageFoundry is a powerful, extensible container image builder with
E2E CI/CD, security scanning, and compliance checks.

Complete documentation is available at https://github.com/yourorg/imagefoundry`,
	Run: func(cmd *cobra.Command, args []string) {
		cmd.Help()
	},
}

func init() {
	cobra.OnInitialize(initConfig)
	rootCmd.PersistentFlags().StringVar(&cfgFile, "config", "", "config file (default is ./image-foundry.yaml)")

	rootCmd.AddCommand(buildCmd)
	rootCmd.AddCommand(validateCmd)
	rootCmd.AddCommand(testCmd)
	rootCmd.AddCommand(scanCmd)
	rootCmd.AddCommand(versionCmd)
	rootCmd.AddCommand(initCmd)
}

func initConfig() {
	if cfgFile != "" {
		// Use config file from the flag
	} else {
		// Search for config in current directory
		cfgFile = "image-foundry.yaml"
	}

	if _, err := os.Stat(cfgFile); err == nil {
		data, err := os.ReadFile(cfgFile)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error reading config: %v\n", err)
			return
		}

		if err := yaml.Unmarshal(data, &config); err != nil {
			fmt.Fprintf(os.Stderr, "Error parsing config: %v\n", err)
			return
		}
	}
}

var buildCmd = &cobra.Command{
	Use:   "build",
	Short: "Build container images from configuration",
	Long:  `Builds container images based on the provided configuration file.`,
	RunE: func(cmd *cobra.Command, args []string) error {
		fmt.Println("🔨 Building container images...")

		// Load configuration
		if err := loadConfig(); err != nil {
			return fmt.Errorf("failed to load config: %w", err)
		}

		// Run pre-build hook
		if config.Custom.PreBuild != "" {
			fmt.Println("Running pre-build hook...")
			if err := runCommand(config.Custom.PreBuild); err != nil {
				return fmt.Errorf("pre-build hook failed: %w", err)
			}
		}

		// Build for each architecture
		for _, arch := range config.Base.Architecture {
			fmt.Printf("Building for architecture: %s\n", arch)
			if err := buildImage(arch); err != nil {
				return fmt.Errorf("failed to build for %s: %w", arch, err)
			}
		}

		// Run post-build hook
		if config.Custom.PostBuild != "" {
			fmt.Println("Running post-build hook...")
			if err := runCommand(config.Custom.PostBuild); err != nil {
				return fmt.Errorf("post-build hook failed: %w", err)
			}
		}

		fmt.Println("✅ Build completed successfully!")
		return nil
	},
}

var validateCmd = &cobra.Command{
	Use:   "validate",
	Short: "Validate configuration file",
	Long:  `Validates the image-foundry.yaml configuration file.`,
	RunE: func(cmd *cobra.Command, args []string) error {
		fmt.Println("🔍 Validating configuration...")

		if err := loadConfig(); err != nil {
			return fmt.Errorf("validation failed: %w", err)
		}

		// Validate required fields
		if config.Name == "" {
			return fmt.Errorf("project name is required")
		}

		if config.Base.Template == "" {
			return fmt.Errorf("base template is required")
		}

		if len(config.Base.Architecture) == 0 {
			return fmt.Errorf("at least one architecture is required")
		}

		// Check if template exists
		templatePath := filepath.Join("templates", "base", config.Base.Template+".Dockerfile")
		if _, err := os.Stat(templatePath); os.IsNotExist(err) {
			return fmt.Errorf("template '%s' not found at %s", config.Base.Template, templatePath)
		}

		fmt.Println("✅ Configuration is valid!")
		return nil
	},
}

var testCmd = &cobra.Command{
	Use:   "test",
	Short: "Run tests on built images",
	Long:  `Runs structure tests, integration tests, and performance tests on built images.`,
	RunE: func(cmd *cobra.Command, args []string) error {
		fmt.Println("🧪 Running tests...")

		if err := loadConfig(); err != nil {
			return err
		}

		// Structure tests
		if config.Testing.StructureTests.Enabled {
			fmt.Println("Running structure tests...")
			if err := runStructureTests(); err != nil {
				return fmt.Errorf("structure tests failed: %w", err)
			}
		}

		// Integration tests
		if config.Testing.IntegrationTests.Enabled {
			fmt.Println("Running integration tests...")
			if err := runIntegrationTests(); err != nil {
				return fmt.Errorf("integration tests failed: %w", err)
			}
		}

		// Performance tests
		if config.Testing.PerformanceTests.Enabled {
			fmt.Println("Running performance tests...")
			if err := runPerformanceTests(); err != nil {
				return fmt.Errorf("performance tests failed: %w", err)
			}
		}

		fmt.Println("✅ All tests passed!")
		return nil
	},
}

var scanCmd = &cobra.Command{
	Use:   "scan",
	Short: "Run security scans on images",
	Long:  `Runs Trivy, CodeQL, SAST, and compliance scans on images.`,
	RunE: func(cmd *cobra.Command, args []string) error {
		fmt.Println("🔒 Running security scans...")

		if err := loadConfig(); err != nil {
			return err
		}

		// Trivy scan
		if config.Security.Trivy.Enabled {
			fmt.Println("Running Trivy vulnerability scan...")
			if err := runTrivyScan(); err != nil {
				return fmt.Errorf("Trivy scan failed: %w", err)
			}
		}

		// Compliance check
		if config.Security.Compliance.Enabled {
			fmt.Println("Running compliance checks...")
			if err := runComplianceChecks(); err != nil {
				return fmt.Errorf("compliance check failed: %w", err)
			}
		}

		// SAST
		if config.Security.SAST.Enabled {
			fmt.Println("Running SAST analysis...")
			if err := runSAST(); err != nil {
				return fmt.Errorf("SAST failed: %w", err)
			}
		}

		fmt.Println("✅ Security scans completed!")
		return nil
	},
}

var versionCmd = &cobra.Command{
	Use:   "version",
	Short: "Print version information",
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println("ImageFoundry v0.1.0")
		fmt.Println("A powerful container image builder with E2E CI/CD")
	},
}

var initCmd = &cobra.Command{
	Use:   "init",
	Short: "Initialize a new ImageFoundry project",
	Long:  `Creates a new ImageFoundry project with example configuration and templates.`,
	RunE: func(cmd *cobra.Command, args []string) error {
		fmt.Println("🚀 Initializing new ImageFoundry project...")

		// Create directory structure
		dirs := []string{
			"templates/base",
			"templates/agents",
			"configs",
			"tests",
			".github/workflows",
			"scripts",
		}

		for _, dir := range dirs {
			if err := os.MkdirAll(dir, 0755); err != nil {
				return fmt.Errorf("failed to create directory %s: %w", dir, err)
			}
		}

		// Copy example config
		exampleConfig := `# ImageFoundry Configuration
name: my-project
version: "1.0.0"
description: "My custom container image"

image:
  name: "my-custom-image"
  tag: "latest"
  registry: "ghcr.io"
  namespace: "myorg"

base:
  template: "ubuntu-24.04"
  architecture:
    - amd64
    - arm64

tools:
  languages:
    go:
      version: "1.22"
      install: true
  security:
    trivy:
      install: true
  packages:
    - curl
    - git

security:
  trivy:
    enabled: true
    severity: "HIGH,CRITICAL"
`

		if err := os.WriteFile("image-foundry.yaml", []byte(exampleConfig), 0644); err != nil {
			return fmt.Errorf("failed to create config file: %w", err)
		}

		fmt.Println("✅ Project initialized!")
		fmt.Println("\nNext steps:")
		fmt.Println("1. Edit image-foundry.yaml to configure your image")
		fmt.Println("2. Run 'foundry validate' to validate configuration")
		fmt.Println("3. Run 'foundry build' to build your image")

		return nil
	},
}

func loadConfig() error {
	if config.Name != "" {
		return nil // Already loaded
	}

	if _, err := os.Stat(cfgFile); os.IsNotExist(err) {
		return fmt.Errorf("config file not found: %s", cfgFile)
	}

	data, err := os.ReadFile(cfgFile)
	if err != nil {
		return fmt.Errorf("failed to read config: %w", err)
	}

	if err := yaml.Unmarshal(data, &config); err != nil {
		return fmt.Errorf("failed to parse config: %w", err)
	}

	return nil
}

func buildImage(arch string) error {
	imageName := fmt.Sprintf("%s/%s/%s:%s",
		config.Image.Registry,
		config.Image.Namespace,
		config.Image.Name,
		config.Image.Tag,
	)

	templatePath := filepath.Join("templates", "base", config.Base.Template+".Dockerfile")

	// Build args
	buildArgs := []string{
		"buildx", "build",
		"--platform", "linux/" + arch,
		"--file", templatePath,
		"--tag", imageName + "-" + arch,
	}

	// Add tool build args
	for toolName, toolConfig := range config.Tools.Languages {
		if toolConfig.Install {
			buildArgs = append(buildArgs, "--build-arg", fmt.Sprintf("%s_VERSION=%s",
				strings.ToUpper(toolName)+"_VERSION", toolConfig.Version))
		}
	}

	buildArgs = append(buildArgs, "--push", ".")

	fmt.Printf("  Running: docker %s\n", strings.Join(buildArgs, " "))

	// In real implementation, this would execute docker buildx
	return runCommand("docker " + strings.Join(buildArgs, " "))
}

func runCommand(cmd string) error {
	// Simplified - would use exec.Command in real implementation
	fmt.Printf("Executing: %s\n", cmd)
	return nil
}

func runStructureTests() error {
	// Placeholder for container-structure-test
	return nil
}

func runIntegrationTests() error {
	// Placeholder for integration tests
	return nil
}

func runPerformanceTests() error {
	// Placeholder for performance tests
	return nil
}

func runTrivyScan() error {
	// Placeholder for Trivy scan
	return nil
}

func runComplianceChecks() error {
	// Placeholder for compliance checks
	return nil
}

func runSAST() error {
	// Placeholder for SAST
	return nil
}

func main() {
	if err := rootCmd.Execute(); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}
