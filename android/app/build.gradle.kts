plugins { id("com.android.application") }
android {
 namespace = "com.oanarinaldi.wakemeup"
 compileSdk = 36
 defaultConfig { applicationId = "com.oanarinaldi.wakemeup"; minSdk = 29; targetSdk = 36; versionCode = 1; versionName = "1.0"; testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"; buildConfigField("String", "PLAY_PUBLIC_KEY", "\"${providers.environmentVariable("WAKE_PLAY_PUBLIC_KEY").getOrElse("")}\"") }
 buildFeatures { buildConfig = true }
 compileOptions { sourceCompatibility = JavaVersion.VERSION_17; targetCompatibility = JavaVersion.VERSION_17 }
 signingConfigs { providers.environmentVariable("WAKE_KEYSTORE").orNull?.let { create("upload") { storeFile = file(it); storePassword = providers.environmentVariable("WAKE_STORE_PASSWORD").get(); keyAlias = "upload"; keyPassword = providers.environmentVariable("WAKE_KEY_PASSWORD").get() } } }
 buildTypes { release { signingConfig = signingConfigs.findByName("upload"); isMinifyEnabled = true; proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro") } }
}
dependencies {
 implementation("androidx.activity:activity:1.13.0")
 implementation("androidx.webkit:webkit:1.15.0")
 implementation("com.android.billingclient:billing:8.3.0")
 implementation("androidx.camera:camera-camera2:1.5.3")
 implementation("androidx.camera:camera-lifecycle:1.5.3")
 implementation("androidx.camera:camera-view:1.5.3")
 implementation("com.google.zxing:core:3.5.4")
 implementation("com.google.ai.edge.litert:litert:1.4.1")
 testImplementation("junit:junit:4.13.2")
 testImplementation("org.json:json:20250517")
 androidTestImplementation("androidx.test:runner:1.7.0")
 androidTestImplementation("androidx.test.ext:junit:1.3.0")
}
