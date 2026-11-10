import SwiftUI

/// Same email and password as the web app; the account and its data are shared.
struct SignInView: View {
    @EnvironmentObject var store: Store
    @State private var email = ""
    @State private var password = ""
    @State private var busy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer()
            Text("Weekly Direction")
                .font(Theme.serif(34))
                .foregroundStyle(Theme.tx)
            VStack(spacing: 12) {
                TextField("Email", text: $email)
                    .textContentType(.username)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("Password", text: $password)
                    .textContentType(.password)
            }
            .padding(16)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.r(16)))
            .foregroundStyle(Theme.tx)

            if let e = store.error {
                Text(e).font(.footnote).foregroundStyle(.red)
            }

            Button {
                busy = true
                Task { await store.signIn(email: email, password: password); busy = false }
            } label: {
                Text(busy ? "Signing in…" : "Sign in")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Theme.ac, in: RoundedRectangle(cornerRadius: Theme.r(14)))
                    .foregroundStyle(Theme.onAc)
            }
            .disabled(busy || email.isEmpty || password.isEmpty)
            Spacer()
        }
        .padding(24)
    }
}
