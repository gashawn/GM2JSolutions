# 🚀 GM2J Orchestrator v2.5: Agentic SDLC Pipeline

## 🏗️ Architecture Overview
The **Orchestrator v2.5** is an Intelligent Infrastructure Agent designed to bridge the gap between business requirements and AWS Well-Architected technical implementation. It utilizes a state-machine driven pipeline (inspired by LangGraph/SDLC patterns) to ensure high-quality, compliant deployments.

### 🧩 Core Components
- **Requirement Analyst Node:** Interprets workload metadata (Scale, HA, Compliance).
- **Architect Node:** Generates modular Terraform HCL following enterprise best practices.
- **Governance Node:** Performs automated SOC2-Ready & Well-Architected pre-flight checks.
- **Orchestration Sync:** Multi-branch GitOps synchronization ("develop" for staging, "main" for prod).

## 🛡️ Quality Control & Cost Optimization
The agentic nature of this pipeline serves as a critical barrier against **out-of-specification** setups.

1. **Human-in-the-Loop (HITL) Oversight:** By default, the system operates in Manual Mode, requiring human validation of the generated HCL before GitHub sync. This ensures no wildcards or "over-provisioned" instances are deployed without justification.
2. **Cost Avoidance:** The Orchestrator automatically selects instance sizes based on environment tiers (e.g., `t3.micro` for staging vs `t3.medium` for prod) to prevent accidental high-cost resource allocation.
3. **Specification Enforcement:** Every deployment is gated by a Governance Scan. If a configuration violates least-privilege or encryption standards, the pipeline halts, requiring remediation.

## ⚙️ Development Flow
- **Staging:** Pushes to the "develop" branch for integration testing.
- **Production:** Pushes directly to "main" following final architect approval.