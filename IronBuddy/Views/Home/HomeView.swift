//
//  HomeView.swift
//  IronBuddy

import Observation
import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Logo
                VStack(spacing: 8) {
                    Image("IronBuddyLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: Theme.accent.opacity(0.3), radius: 12, y: 4)
                    Text("举铁有伴儿，AI更懂你")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)
                }
                .padding(.top, 16)

                // 开始训练 CTA
                Button {
                    appState.path.append(AppRoute.actionSelect)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("开始训练")
                                .font(.headline.weight(.bold))
                            Text("俯卧撑 / 深蹲 / 硬拉 / 卧推")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        Spacer()
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title2)
                    }
                    .padding(20)
                    .background(Theme.primaryGradient)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(.white.opacity(0.15), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
                .shadow(color: .orange.opacity(0.25), radius: 16, y: 6)
                .padding(.horizontal)

                // 体态评估
                Button {
                    appState.path.append(AppRoute.flexibilityTest)
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "figure.walk")
                            .font(.title2)
                            .foregroundStyle(Theme.techCyan)
                            .frame(width: 40, height: 40)
                            .background(Theme.techCyan.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("体态评估")
                                .font(.headline)
                                .foregroundStyle(Theme.primaryText)
                            Text("首次训练前进行柔韧性测试")
                                .font(.caption)
                                .foregroundStyle(Theme.secondaryText)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(Theme.tertiaryText)
                    }
                    .padding(14)
                    .background(Theme.bgCard)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Theme.subtleBorder, lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal)

                // 训练计划
                Button {
                    appState.path.append(AppRoute.trainingPlan)
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "list.clipboard.fill")
                            .font(.title2)
                            .foregroundStyle(.green)
                            .frame(width: 40, height: 40)
                            .background(Color.green.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("训练计划")
                                .font(.headline)
                                .foregroundStyle(Theme.primaryText)
                            Text("预设计划，科学训练")
                                .font(.caption)
                                .foregroundStyle(Theme.secondaryText)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(Theme.tertiaryText)
                    }
                    .padding(14)
                    .background(Theme.bgCard)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Theme.subtleBorder, lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal)

                // 底部导航
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    NavCard(icon: "chart.bar.fill", title: "统计", destination: .stats)
                    NavCard(icon: "trophy.fill", title: "成就", destination: .achievements)
                    NavCard(icon: "clock.arrow.circlepath", title: "历史", destination: .history)
                    NavCard(icon: "person.circle", title: "资料", destination: .profile)
                    NavCard(icon: "gearshape", title: "设置", destination: .settings)
                }
                .padding(.horizontal)

                Spacer(minLength: 24)
            }
        }
        .background(Theme.bgPrimary)
        .navigationTitle("铁伴儿")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationStack {
        HomeView()
            .environment(AppState())
    }
}
