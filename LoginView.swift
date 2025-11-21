//
//  LoginView.swift
//  offlineweb
//
//  Created by Robin Lovoj on 09/11/25.
//

import SwiftUI
import UIKit

struct LoginView: View {
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var storeType: String = "Designer"
    @State private var role: String = "admin"
    @State private var isPasswordVisible: Bool = false
    @State private var isLoggedIn: Bool = UserDataManager.shared.isLoggedIn()
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var emailError: String?
    @State private var passwordError: String?
    @State private var showSuccessSnackbar: Bool = false
    @FocusState private var focusedField: Field?
    
    enum Field {
        case email, password
    }
    
    @State private var progressAnimation: Bool = false
    
    // MARK: - Validation Helper
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    // Computed properties for validation
    private var isEmailValid: Bool {
        !email.isEmpty && isValidEmail(email)
    }
    
    private var isPasswordValid: Bool {
        !password.isEmpty && password.count >= 6
    }
    
    private var isFormValid: Bool {
        isEmailValid && isPasswordValid
    }
    
    var body: some View {
        Group {
            if isLoggedIn {
                ContentView()
            } else {
                loginContentView
            }
        }
        .onAppear {
            if UserDataManager.shared.isLoggedIn() {
                isLoggedIn = true
            }
        }
    }
    
    private var loginContentView: some View {
        ZStack {
            // Dark gradient purple background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.12, green: 0.08, blue: 0.2),
                    Color(red: 0.15, green: 0.1, blue: 0.25),
                    Color(red: 0.1, green: 0.06, blue: 0.18)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top bar with rotation button
                HStack {
                    Spacer()
                    RotationToggleButton()
                        .padding(.trailing, 20)
                        .padding(.top, 10)
                }
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        Spacer()
                            .frame(height: 40)
                        
                        // Logo or App Icon - Centered
                        VStack(spacing: 0) {
                            if let image = UIImage(named: "SplashImage") {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 100, height: 100)
                            } else {
                                Image(systemName: "cube.box.fill")
                                    .font(.system(size: 70))
                                    .foregroundColor(Color(red: 0.9, green: 0.3, blue: 0.7))
                            }
                        }
                        .padding(.bottom, 32)
                        
                        // Welcome Back text - Centered
                        Text("Welcome Back")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.bottom, 8)
                        
                        // Tagline - Centered
                        Text("Experience 3D content without boundaries")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(.white.opacity(0.75))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                            .padding(.bottom, 48)
                    
                        // Login form - Clean white input fields
                        VStack(spacing: 24) {
                            // Email field
                            emailFieldView
                            
                            // Password field
                            passwordFieldView
                            
                            // Forgot password
                            HStack {
                                Spacer()
                                Button(action: {
                                    // Handle forgot password
                                }) {
                                    Text("Forgot Password?")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(Color(red: 0.9, green: 0.3, blue: 0.7))
                                }
                            }
                            .padding(.top, 4)
                        
                            // General error message
                            if let errorMessage = errorMessage {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.red)
                                    
                                    Text(errorMessage)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.red)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.leading, 4)
                                .padding(.top, 4)
                            }
                            
                            // SIGN IN button
                            signInButton
                        }
                        .padding(.horizontal, 28)
                    }
                    
                    Spacer()
                        .frame(height: 30)
                }
            }
            
            // Success Snackbar
            SnackbarView(
                message: "Successfully logged in!",
                icon: "checkmark.circle.fill",
                backgroundColor: Color(red: 0.2, green: 0.7, blue: 0.3),
                isShowing: $showSuccessSnackbar
            )
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: focusedField)
    }
    
    private var emailFieldView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Email")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
            
            HStack(spacing: 12) {
                Image(systemName: "envelope.fill")
                    .foregroundColor(Color(red: 0.9, green: 0.3, blue: 0.7))
                    .font(.system(size: 16))
                
                ZStack(alignment: .leading) {
                    if email.isEmpty {
                        Text("Enter your email")
                            .foregroundColor(.gray.opacity(0.5))
                            .font(.system(size: 16))
                    }
                    
                    TextField("", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .foregroundColor(.black)
                        .font(.system(size: 16))
                        .focused($focusedField, equals: .email)
                        .onChange(of: email) { newValue in
                            validateEmail(newValue)
                        }
                }
                
                if !email.isEmpty && isEmailValid {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 20))
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        emailError != nil ? .red :
                        (focusedField == .email ? Color(red: 0.9, green: 0.3, blue: 0.7) : Color.clear),
                        lineWidth: emailError != nil || focusedField == .email ? 2.5 : 0
                    )
            )
            
            // Error message for email
            if let emailError = emailError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                    Text(emailError)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.red)
                }
                .padding(.leading, 4)
            }
        }
    }
    
    private var passwordFieldView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Password")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
            
            HStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .foregroundColor(Color(red: 0.9, green: 0.3, blue: 0.7))
                    .font(.system(size: 16))
                
                ZStack(alignment: .leading) {
                    if password.isEmpty {
                        Text("Enter your password")
                            .foregroundColor(.gray.opacity(0.5))
                            .font(.system(size: 16))
                    }
                    
                    if isPasswordVisible {
                        TextField("", text: $password)
                            .textContentType(.password)
                            .foregroundColor(.black)
                            .font(.system(size: 16))
                            .focused($focusedField, equals: .password)
                            .onChange(of: password) { newValue in
                                validatePassword(newValue)
                            }
                    } else {
                        SecureField("", text: $password)
                            .textContentType(.password)
                            .foregroundColor(.black)
                            .font(.system(size: 16))
                            .focused($focusedField, equals: .password)
                            .onChange(of: password) { newValue in
                                validatePassword(newValue)
                            }
                    }
                }
                
                // Eye toggle button
                Button(action: {
                    isPasswordVisible.toggle()
                }) {
                    Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                        .foregroundColor(Color(red: 0.9, green: 0.3, blue: 0.7))
                        .font(.system(size: 18))
                }
                
                if !password.isEmpty && isPasswordValid {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 20))
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        passwordError != nil ? .red :
                        (focusedField == .password ? Color(red: 0.9, green: 0.3, blue: 0.7) : Color.clear),
                        lineWidth: passwordError != nil || focusedField == .password ? 2.5 : 0
                    )
            )
            
            // Error message for password
            if let passwordError = passwordError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                    Text(passwordError)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.red)
                }
                .padding(.leading, 4)
            }
        }
    }
    
    private var signInButton: some View {
        Button(action: {
            handleLogin()
        }) {
            ZStack {
                // Pink background with gradient
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.9, green: 0.3, blue: 0.7),
                                Color(red: 0.85, green: 0.25, blue: 0.65)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: isLoading ? 80 : 56)
                    .shadow(color: Color(red: 0.9, green: 0.3, blue: 0.7).opacity(0.4), radius: 12, x: 0, y: 6)
                
                if isLoading {
                    loadingView
                } else {
                    Text("SIGN IN")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .frame(height: 56)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.top, 8)
        .disabled(!isFormValid || isLoading)
        .opacity((!isFormValid || isLoading) ? 0.6 : 1.0)
        .animation(.spring(response: 0.3), value: isLoading)
    }
    
    private var loadingView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.1)
                
                Text("Signing In...")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            // Animated progress bar
            VStack(spacing: 0) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background track
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 4)
                        
                        // Animated progress fill
                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white,
                                        Color.white.opacity(0.95),
                                        Color.white.opacity(0.85)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: animatedProgressWidth(geometry: geometry), height: 4)
                            .shadow(color: .white.opacity(0.6), radius: 3, x: 0, y: 0)
                            .animation(
                                Animation.linear(duration: 1.0)
                                    .repeatForever(autoreverses: true),
                                value: progressAnimation
                            )
                    }
                }
                .frame(height: 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 4)
            .onAppear {
                if isLoading {
                    progressAnimation = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation {
                            progressAnimation = true
                        }
                    }
                }
            }
            .onChange(of: isLoading) { newValue in
                if newValue {
                    progressAnimation = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(
                            Animation.linear(duration: 1.0)
                                .repeatForever(autoreverses: true)
                        ) {
                            progressAnimation = true
                        }
                    }
                } else {
                    progressAnimation = false
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private func handleLogin() {
        // Dismiss keyboard
        focusedField = nil
        
        // Clear previous errors
        errorMessage = nil
        emailError = nil
        passwordError = nil
        
        // Validate all fields
        var hasErrors = false
        
        // Validate email
        if email.isEmpty {
            emailError = "Email is required"
            hasErrors = true
        } else if !isValidEmail(email) {
            emailError = "Please enter a valid email"
            hasErrors = true
        }
        
        // Validate password
        if password.isEmpty {
            passwordError = "Password is required"
            hasErrors = true
        } else if password.count < 6 {
            passwordError = "Password must be at least 6 characters"
            hasErrors = true
        }
        
        if hasErrors {
            // Haptic feedback for error
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
            return
        }
        
        // Add haptic feedback for success
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // Start loading
        isLoading = true
        progressAnimation = false
        
        // Start progress animation with repeating animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(
                Animation.linear(duration: 1.0)
                    .repeatForever(autoreverses: true)
            ) {
                progressAnimation = true
            }
        }
        
        // Call API
        Task {
            do {
                let response = try await AuthService.shared.login(
                    email: email,
                    password: password,
                    storeType: storeType,
                    role: role
                )
                
                // Success - show snackbar then navigate
                await MainActor.run {
                    isLoading = false
                    progressAnimation = false
                    
                    // Show success snackbar
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showSuccessSnackbar = true
                    }
                    
                    // Haptic feedback for success
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    
                    // Navigate to home page after snackbar
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isLoggedIn = true
                        }
                    }
                }
            } catch {
                // Handle error
                await MainActor.run {
                    isLoading = false
                    progressAnimation = false
                    
                    if let authError = error as? AuthError {
                        let errorDesc = authError.errorDescription ?? "Login failed"
                        
                        // Check if it's a password/credential error
                        if errorDesc.lowercased().contains("password") ||
                           errorDesc.lowercased().contains("invalid") ||
                           errorDesc.lowercased().contains("incorrect") ||
                           errorDesc.lowercased().contains("unauthorized") {
                            passwordError = "Incorrect password"
                            errorMessage = "Invalid email or password"
                        } else if errorDesc.lowercased().contains("email") ||
                                  errorDesc.lowercased().contains("user") ||
                                  errorDesc.lowercased().contains("not found") {
                            emailError = "Email not found"
                            errorMessage = "Invalid email or password"
                        } else {
                            errorMessage = errorDesc
                        }
                    } else {
                        errorMessage = error.localizedDescription
                    }
                    
                    // Haptic feedback for error
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.error)
                }
            }
        }
    }
    
    // MARK: - Validation Functions
    private func validateEmail(_ email: String) {
        if email.isEmpty {
            emailError = nil
        } else if !isValidEmail(email) {
            emailError = "Invalid email format"
        } else {
            emailError = nil
        }
    }
    
    private func validatePassword(_ password: String) {
        if password.isEmpty {
            passwordError = nil
        } else if password.count < 6 {
            passwordError = "Password must be at least 6 characters"
        } else {
            passwordError = nil
        }
    }
    
    // Helper function for animated progress width
    private func animatedProgressWidth(geometry: GeometryProxy) -> CGFloat {
        if isLoading {
            // Animate from 20% to 85% width for smooth animation
            let minWidth = geometry.size.width * 0.2
            let maxWidth = geometry.size.width * 0.85
            if progressAnimation {
                return maxWidth
            } else {
                return minWidth
            }
        }
        return 0
    }
}

#Preview {
    LoginView()
}
