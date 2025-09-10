<h1 align="center">🤖 PoseMatch</h1>

<p align="center">
  <em>A SwiftUI library built on Apple's Vision framework that compares two human body poses and returns a similarity score out of 10.</em>
</p>

<p align="center">
  <a href="LICENSE">
    <img src="https://img.shields.io/badge/License-Apache_2.0-blue.svg" alt="License">
  </a>
  <img src="https://img.shields.io/badge/SwiftUI-Compatible-orange.svg" alt="SwiftUI">
  <img src="https://img.shields.io/badge/Vision-Framework-green.svg" alt="Vision">
</p>

---

<h2>✨ Features</h2>
<ul>
  <li>📸 Capture a <strong>reference pose</strong> from a photo</li>
  <li>🎥 Compare against a <strong>live camera pose</strong> in real time</li>
  <li>🤖 Powered by <strong>Vision framework</strong> for body landmark detection</li>
  <li>📊 Returns a <strong>score (0–10)</strong> based on:
    <ul>
      <li>Pose similarity</li>
      <li>Clarity of the photo</li>
      <li>Angle alignment</li>
    </ul>
  </li>
</ul>

---

<h2>🧘 Use Cases</h2>
<ul>
  <li><strong>Yoga apps</strong> → Ensure users hold the correct position</li>
  <li><strong>Dance training</strong> → Match movements with instructors</li>
  <li><strong>Fitness coaching</strong> → Compare posture and form</li>
  <li><strong>Rehabilitation</strong> → Track exercise accuracy over time</li>
</ul>

---

<h2>📦 Installation</h2>
<p><strong>Swift Package Manager</strong></p>
<ol>
  <li>In Xcode, go to: <code>File → Add Packages...</code></li>
  <li>Enter repo URL:<br>
    <code>https://github.com/shubhamkachhiya/PoseMatch</code>
  </li>
  <li>Add <code>PoseMatch</code> as a dependency.</li>
</ol>

---

<h2>📂 Examples</h2> 
<p> This repository includes <strong>example projects</strong> that demonstrate how to integrate and use <code>PoseMatch</code> in real apps. </p>
<ul> 
  <li>✅ Download the repo</li>
  <li>✅ Open the <code>PoseMatchExample</code> folder in Xcode</li>
  <li>✅ Run the sample project on your device.</li> 
</ul> 
<p> By exploring the example code, you’ll quickly understand how to capture poses, compare them, and display similarity scores in your own apps. </p>

<h2>⚠️ Important Note</h2>
<p> This library uses the certain features of the <strong>Vision framework</strong> that are only available on real devices. </p>
<ul> <li>🚫 The iOS Simulator does not support these APIs.</li>
  <li>✅ Always test and run your project on a <strong>real iPhone or iPad</strong>.</li> 
</ul>

<h2>📜 License</h2>
<p>This project is licensed under the <a href="LICENSE">Apache 2.0 License</a></p>

