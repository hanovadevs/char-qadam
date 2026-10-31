package com.stepsy.run
import android.app.Activity
import android.os.Bundle
import android.content.Intent
import android.net.Uri
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Button

class PrivacyPolicyActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        title = "Stepsy step-data privacy"
        val layout = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; setPadding(32, 48, 32, 32) }
        layout.addView(TextView(this).apply {
            textSize = 18f
            text = "Stepsy reads step totals only with your permission. Daily totals, dates and sources are synced to our server to calculate points, show history and rankings, and prevent misuse. Background syncing is best effort. We do not collect GPS routes or sell health data. You can revoke access in Health Connect and delete your account in Stepsy Profile. AI support does not automatically receive your health history."
        })
        val policyUrl = getString(com.stepsy.run.R.string.public_privacy_url)
        if (policyUrl.startsWith("https://")) {
            layout.addView(Button(this).apply {
                text = "Read full privacy policy"
                setOnClickListener { startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(policyUrl))) }
            })
        }
        setContentView(layout)
    }
}
