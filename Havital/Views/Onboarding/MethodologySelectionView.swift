import SwiftUI

struct MethodologySelectionView: View {
    @EnvironmentObject private var viewModel: OnboardingFeatureViewModel
    @ObservedObject private var coordinator = OnboardingCoordinator.shared

    var body: some View {
        OnboardingPageTemplate(
            ctaTitle: NSLocalizedString("onboarding.next", comment: "Next"),
            ctaEnabled: viewModel.selectedMethodology != nil,
            isLoading: false,
            skipTitle: nil,
            ctaAccessibilityId: "Methodology_NextButton",
            ctaAction: {
                handleNextStep()
            },
            skipAction: nil
        ) {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(NSLocalizedString("onboarding.methodology_description", comment: "Different methodologies focus on different training approaches."))
                        .font(AppFont.bodySmall())
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Content
                if viewModel.isLoadingMethodologies {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)

                        Text(NSLocalizedString("onboarding.loading_methodologies", comment: "Loading methodologies..."))
                            .font(AppFont.bodySmall())
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)

                } else if let error = viewModel.methodologyError {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(AppFont.systemScaled(size: 48))
                            .foregroundColor(.orange)

                        Text(error)
                            .font(AppFont.bodySmall())
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        Button(NSLocalizedString("common.retry", comment: "Retry")) {
                            Task {
                                if let targetType = viewModel.selectedTargetTypeV2 {
                                    await viewModel.loadMethodologiesForTargetType(targetType.id)
                                }
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()

                } else {
                    // Methodology Cards
                    VStack(spacing: 16) {
                        ForEach(sortedMethodologies) { methodology in
                            MethodologyCard(
                                methodology: methodology,
                                isDefault: isDefaultMethodology(methodology),
                                isSelected: viewModel.selectedMethodology?.id == methodology.id
                            ) {
                                viewModel.selectedMethodology = methodology
                            }
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("Methodology_Screen")
        .navigationTitle(NSLocalizedString("onboarding.methodology_nav_title", comment: "Training Methodology"))
        .task {
            Logger.debug("[MethodologySelectionView] .task: Loading methodologies...")

            if let targetTypeId = coordinator.selectedTargetTypeId {
                Logger.debug("[MethodologySelectionView] Target type ID from coordinator: \(targetTypeId)")

                await viewModel.loadTargetTypes()
                if let targetType = viewModel.availableTargetTypes.first(where: { $0.id == targetTypeId }) {
                    viewModel.selectedTargetTypeV2 = targetType
                    Logger.debug("[MethodologySelectionView] Set selectedTargetTypeV2: \(targetType.id)")
                }

                await viewModel.loadMethodologiesForTargetType(targetTypeId)
                Logger.info("[MethodologySelectionView] Loaded \(viewModel.availableMethodologies.count) methodologies")
            } else {
                Logger.error("[MethodologySelectionView] No targetTypeId in coordinator!")
            }
        }
    }

    // MARK: - Sorted Methodologies

    private var sortedMethodologies: [MethodologyV2] {
        let preferredOrder = ["paceriz", "norwegian", "hansons", "polarized"]

        return viewModel.availableMethodologies.sorted { m1, m2 in
            let index1 = preferredOrder.firstIndex(of: m1.id) ?? Int.max
            let index2 = preferredOrder.firstIndex(of: m2.id) ?? Int.max
            return index1 < index2
        }
    }

    private func isDefaultMethodology(_ methodology: MethodologyV2) -> Bool {
        guard let targetType = viewModel.selectedTargetTypeV2 else { return false }
        return methodology.id == targetType.defaultMethodology
    }

    private func handleNextStep() {
        if let selectedMethodology = viewModel.selectedMethodology {
            coordinator.selectedMethodologyId = selectedMethodology.id
            Logger.debug("[MethodologySelectionView] Saved methodologyId to coordinator: \(selectedMethodology.id)")
        }

        let isRaceTarget = coordinator.selectedTargetTypeId == "race_run"

        if isRaceTarget {
            if coordinator.shouldNavigateToStartStageAfterMethodology {
                Logger.debug("[MethodologySelectionView] Race target with tight schedule, navigating to startStage")
                coordinator.navigate(to: .startStage)
            } else {
                Logger.debug("[MethodologySelectionView] Race target with sufficient schedule, navigating to trainingDays")
                coordinator.navigate(to: .trainingDays)
            }
        } else {
            Logger.debug("[MethodologySelectionView] Non-race target, navigating to trainingWeeksSetup")
            coordinator.navigate(to: .trainingWeeksSetup)
        }
    }
}

// MARK: - MethodologyCard Component

struct MethodologyCard: View {
    let methodology: MethodologyV2
    let isDefault: Bool
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack(spacing: 12) {
                    Image(systemName: iconForMethodology(methodology.id))
                        .font(AppFont.systemScaled(size: 28))
                        .foregroundColor(isSelected ? .accentColor : .secondary)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(methodology.name)
                                .font(AppFont.headline())
                                .foregroundColor(.primary)

                            if isDefault {
                                Text(NSLocalizedString("onboarding.recommended", comment: "Recommended"))
                                    .font(AppFont.captionSmall())
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.accentColor)
                                    .cornerRadius(8)
                            }
                        }

                        Text(String(format: NSLocalizedString("onboarding.methodology_phases", comment: "%d phases"), methodology.phases.count))
                            .font(AppFont.caption())
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(AppFont.systemScaled(size: 24))
                        .foregroundColor(isSelected ? .accentColor : .secondary.opacity(0.3))
                }

                // Description
                Text(methodology.description)
                    .font(AppFont.bodySmall())
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)

                if methodology.crossTrainingEnabled {
                    HStack(spacing: 6) {
                        Image(systemName: "figure.mixed.cardio")
                        Text(NSLocalizedString("onboarding.cross_training_enabled", comment: "Cross-training enabled"))
                    }
                    .font(AppFont.caption())
                    .foregroundColor(.blue)
                    .padding(8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : Color(.systemGray4), lineWidth: isSelected ? 2.5 : 1.5)
            )
            .shadow(color: isSelected ? Color.accentColor.opacity(0.2) : Color.black.opacity(0.05), radius: isSelected ? 8 : 4)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("Methodology_\(methodology.id)")
    }

    private func iconForMethodology(_ id: String) -> String {
        switch id {
        case "paceriz": return "chart.line.uptrend.xyaxis"
        case "polarized": return "waveform.path.ecg"
        case "hansons": return "speedometer"
        case "norwegian": return "mountain.2"
        case "complete_10k": return "figure.run"
        case "balanced_fitness": return "chart.bar"
        case "aerobic_endurance": return "heart.circle"
        default: return "figure.run.circle"
        }
    }
}
