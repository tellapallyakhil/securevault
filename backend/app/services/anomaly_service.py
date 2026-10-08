import math
import numpy as np
from datetime import datetime, timezone
from typing import Dict, Any, List, Tuple
from sklearn.ensemble import IsolationForest

class AnomalyService:
    """
    Behavioral Anomaly Detection Service using Isolation Forest.
    Evaluates user telemetry to detect credential stuffing, anomalous export bursts,
    off-hours access, and atypical PII scraping.
    """

    def __init__(self):
        self.model = IsolationForest(
            n_estimators=100,
            contamination=0.05,
            random_state=42
        )
        self.is_fitted = False
        self._seed_baseline_training()

    def _extract_features(self, telemetry: Dict[str, Any]) -> List[float]:
        """
        Extracts 6 numerical features:
        1. sin(hour) - cyclic time
        2. cos(hour) - cyclic time
        3. access_frequency (events in window)
        4. ip_mismatch_flag (0 or 1)
        5. failed_auth_attempts
        6. high_sensitivity_doc_count
        """
        now = datetime.now(timezone.utc)
        hour = telemetry.get("hour", now.hour + now.minute / 60.0)
        hour_rad = 2 * math.pi * (hour / 24.0)
        
        sin_hour = math.sin(hour_rad)
        cos_hour = math.cos(hour_rad)
        access_freq = float(telemetry.get("access_frequency", 1.0))
        ip_changed = 1.0 if telemetry.get("ip_changed", False) else 0.0
        failed_auth = float(telemetry.get("failed_attempts", 0))
        high_sens_count = float(telemetry.get("high_sens_count", 0))

        return [sin_hour, cos_hour, access_freq, ip_changed, failed_auth, high_sens_count]

    def _seed_baseline_training(self):
        """
        Trains initial baseline on typical user behaviors (work hours 9am-8pm, low error rate, steady access).
        """
        np.random.seed(42)
        n_samples = 400
        
        # Typical user behavior:
        # Hours between 9 and 20 (normal distribution around 14:00)
        hours = np.random.normal(14.0, 3.0, n_samples) % 24
        sin_hours = np.sin(2 * np.pi * (hours / 24.0))
        cos_hours = np.cos(2 * np.pi * (hours / 24.0))
        
        # Normal frequency: 1 to 5 actions
        freq = np.random.exponential(2.0, n_samples) + 1.0
        # Normal IP mismatch is rare (~2%)
        ip_mismatch = np.random.binomial(1, 0.02, n_samples)
        # Normal failed attempts are 0 or rarely 1
        failed_attempts = np.random.binomial(1, 0.03, n_samples)
        # Normal sensitive doc downloads: 0 to 2
        sens_count = np.random.poisson(0.5, n_samples)

        X_train = np.column_stack([sin_hours, cos_hours, freq, ip_mismatch, failed_attempts, sens_count])
        self.model.fit(X_train)
        self.is_fitted = True

    def assess_risk(self, telemetry: Dict[str, Any]) -> Dict[str, Any]:
        """
        Scores an incoming action telemetry using Isolation Forest.
        Returns:
          - is_anomaly: bool (-1 from IsolationForest)
          - anomaly_score: float (raw decision function score, negative = anomalous)
          - risk_level: "LOW" | "ELEVATED" | "CRITICAL"
          - risk_score: 0-100 normalized score
          - reasons: list of detected behavioral anomalies
        """
        features = self._extract_features(telemetry)
        X = np.array([features])
        
        # decision_function returns lower values for anomalies
        raw_score = float(self.model.decision_function(X)[0])
        prediction = int(self.model.predict(X)[0])  # 1 = normal, -1 = anomaly
        
        # Map raw decision function (-0.3 to +0.3 typically) to 0-100 risk score
        normalized_risk = int(np.clip((0.2 - raw_score) * 200, 0, 100))
        
        is_anomaly = (prediction == -1) or (normalized_risk >= 65)
        
        reasons = []
        if telemetry.get("ip_changed"):
            reasons.append("Login / action from unrecognized IP address or ASN")
        if telemetry.get("failed_attempts", 0) >= 3:
            reasons.append(f"Multiple failed authentication attempts ({telemetry['failed_attempts']})")
        if telemetry.get("access_frequency", 0) > 15:
            reasons.append("Abnormally high request velocity (burst activity)")
        if telemetry.get("high_sens_count", 0) >= 4:
            reasons.append("Bulk retrieval of HIGH sensitivity PII records")
            
        now_hour = telemetry.get("hour", datetime.now(timezone.utc).hour)
        if now_hour < 5 or now_hour > 23:
            reasons.append(f"Off-hours access detected (time: {now_hour:.1f}h UTC)")
            
        if not reasons and is_anomaly:
            reasons.append("Unusual multidimensional behavioral trajectory flagged by Isolation Forest")

        if normalized_risk >= 75:
            risk_level = "CRITICAL"
        elif normalized_risk >= 45:
            risk_level = "ELEVATED"
        else:
            risk_level = "LOW"

        return {
            "is_anomaly": is_anomaly,
            "anomaly_score": round(raw_score, 4),
            "risk_score": normalized_risk,
            "risk_level": risk_level,
            "reasons": reasons,
            "timestamp": datetime.now(timezone.utc).isoformat()
        }

anomaly_service = AnomalyService()
