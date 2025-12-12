"""
Clustering and Anomaly Detection Module for Crop Stress Detection Pipeline

Implements K-Means clustering and Isolation Forest anomaly detection.
"""

import numpy as np
from sklearn.cluster import MiniBatchKMeans
from sklearn.ensemble import IsolationForest
from sklearn.preprocessing import StandardScaler
from typing import Dict


class StressAnalyzer:
    """Perform clustering and anomaly detection on embeddings."""
    
    def __init__(self, n_clusters: int = 5, contamination: float = 0.1):
        """
        Initialize stress analyzer.
        
        Args:
            n_clusters: Number of clusters for K-Means
            contamination: Expected proportion of anomalies
        """
        self.n_clusters = n_clusters
        self.contamination = contamination
        self.scaler = StandardScaler()
        self.kmeans = None
        self.isolation_forest = None
        
    def cluster_embeddings(self, embeddings: np.ndarray) -> np.ndarray:
        """
        Perform K-Means clustering on embeddings.
        
        Args:
            embeddings: (N, D) embedding vectors
            
        Returns:
            Cluster labels (N,)
        """
        print(f"Performing K-Means clustering (k={self.n_clusters})...")
        
        # Standardize embeddings
        embeddings_scaled = self.scaler.fit_transform(embeddings)
        
        # K-Means clustering
        self.kmeans = MiniBatchKMeans(
            n_clusters=self.n_clusters,
            random_state=42,
            batch_size=256,
            max_iter=100
        )
        
        cluster_labels = self.kmeans.fit_predict(embeddings_scaled)
        
        # Validate
        assert len(cluster_labels) == len(embeddings), "Label count mismatch"
        assert cluster_labels.min() >= 0, "Invalid cluster labels"
        assert cluster_labels.max() < self.n_clusters, "Cluster label out of range"
        
        # Print distribution
        print(f"[OK] Cluster distribution:")
        for i in range(self.n_clusters):
            count = np.sum(cluster_labels == i)
            print(f"  Cluster {i}: {count} patches ({count/len(cluster_labels)*100:.1f}%)")
        
        return cluster_labels
    
    def detect_anomalies(self, embeddings: np.ndarray) -> tuple:
        """
        Detect anomalies using Isolation Forest.
        
        Args:
            embeddings: (N, D) embedding vectors
            
        Returns:
            Tuple of (anomaly_labels, anomaly_scores)
        """
        print(f"Detecting anomalies (contamination={self.contamination})...")
        
        # Standardize embeddings (use same scaler as clustering)
        embeddings_scaled = self.scaler.transform(embeddings)
        
        # Isolation Forest
        self.isolation_forest = IsolationForest(
            contamination=self.contamination,
            random_state=42,
            n_estimators=100
        )
        
        anomaly_labels = self.isolation_forest.fit_predict(embeddings_scaled)
        anomaly_scores = self.isolation_forest.score_samples(embeddings_scaled)
        
        # Normalize scores to [0, 1] (lower = more anomalous)
        anomaly_scores = (anomaly_scores - anomaly_scores.min()) / (anomaly_scores.max() - anomaly_scores.min())
        
        # Validate
        assert len(anomaly_labels) == len(embeddings), "Label count mismatch"
        assert len(anomaly_scores) == len(embeddings), "Score count mismatch"
        
        num_anomalies = np.sum(anomaly_labels == -1)
        print(f"[OK] Detected {num_anomalies} anomalies ({num_anomalies/len(embeddings)*100:.1f}%)")
        print(f"[OK] Anomaly score range: [{anomaly_scores.min():.3f}, {anomaly_scores.max():.3f}]")
        
        return anomaly_labels, anomaly_scores
    
    def analyze(self, embeddings: np.ndarray) -> Dict:
        """
        Perform complete analysis: clustering + anomaly detection.
        
        Args:
            embeddings: (N, D) embedding vectors
            
        Returns:
            Dictionary with cluster labels, anomaly labels, and scores
        """
        # Clustering
        cluster_labels = self.cluster_embeddings(embeddings)
        
        # Anomaly detection
        anomaly_labels, anomaly_scores = self.detect_anomalies(embeddings)
        
        return {
            'cluster_labels': cluster_labels,
            'anomaly_labels': anomaly_labels,
            'anomaly_scores': anomaly_scores
        }


if __name__ == "__main__":
    # Example usage
    embeddings = np.random.rand(1000, 128)  # 1000 samples, 128-dim embeddings
    
    analyzer = StressAnalyzer(n_clusters=5, contamination=0.1)
    results = analyzer.analyze(embeddings)
    
    print(f"\nResults:")
    print(f"  Cluster labels: {results['cluster_labels'].shape}")
    print(f"  Anomaly labels: {results['anomaly_labels'].shape}")
    print(f"  Anomaly scores: {results['anomaly_scores'].shape}")
