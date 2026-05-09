//
//  ProfileView.swift
//  IronBuddy
//

import SwiftUI

struct ProfileView: View {
    @State private var weight = ""
    @State private var age = ""
    @State private var gender = "未填写"
    @State private var saved = false

    var body: some View {
        Form {
            Section("身体数据") {
                TextField("体重 (kg)", text: $weight)
                    .keyboardType(.decimalPad)
                    .listRowBackground(Theme.bgCard)
                TextField("年龄", text: $age)
                    .keyboardType(.numberPad)
                    .listRowBackground(Theme.bgCard)
                Picker("性别", selection: $gender) {
                    Text("未填写").tag("未填写")
                    Text("男").tag("男")
                    Text("女").tag("女")
                }
                .listRowBackground(Theme.bgCard)
            }
            Section {
                PrimaryButton(title: saved ? "已保存" : "保存") {
                    saveProfile()
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
            Section {
                Text("体重数据用于估算训练热量消耗")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
                    .listRowBackground(Theme.bgCard)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.bgPrimary)
        .foregroundStyle(Theme.primaryText)
        .navigationTitle("个人资料")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadProfile()
        }
    }

    private func loadProfile() {
        let w = UserDefaults.standard.double(forKey: UserDefaultsKeys.profileWeightKg)
        if w > 0 { weight = String(format: "%.1f", w) }

        let a = UserDefaults.standard.integer(forKey: UserDefaultsKeys.profileAge)
        if a > 0 { age = "\(a)" }

        let g = UserDefaults.standard.string(forKey: UserDefaultsKeys.profileGender) ?? "未填写"
        gender = g
    }

    private func saveProfile() {
        if let w = Double(weight), w > 0 {
            UserDefaults.standard.set(w, forKey: UserDefaultsKeys.profileWeightKg)
        } else if !weight.isEmpty {
            return // invalid weight input, don't show success
        }
        if let a = Int(age), a > 0 {
            UserDefaults.standard.set(a, forKey: UserDefaultsKeys.profileAge)
        } else if !age.isEmpty {
            return // invalid age input, don't show success
        }
        UserDefaults.standard.set(gender, forKey: UserDefaultsKeys.profileGender)
        saved = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { @MainActor in
            saved = false
        }
    }
}

#Preview {
    NavigationStack {
        ProfileView()
    }
}
