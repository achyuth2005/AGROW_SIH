"""
Stress Detection Model
=======================

Deep learning model for crop stress detection using spatial-temporal encoding.
Architecture: Spatial CNN → Temporal LSTM → Clustering → Anomaly Detection
"""

import numpy as np
import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers
from sklearn.cluster import KMeans
from sklearn.ensemble import IsolationForest
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import silhouette_score
from typing import Tuple, Dict, List
import warnings
warnings.filterwarnings('ignore')


class SpatialEncoder(keras.Model):
    """
    CNN-based spatial feature extractor.
    Processes each timestamp independently to extract spatial features.
    """
    
    def __init__(self, embedding_dim=128):
        super(SpatialEncoder, self).__init__()
        
        # Convolutional layers
        self.conv1 = layers.Conv2D(32, (3, 3), activation='relu', padding='same')
        self.bn1 = layers.BatchNormalization()
        self.pool1 = layers.MaxPooling2D((2, 2))
        self.dropout1 = layers.Dropout(0.25)
        
        self.conv2 = layers.Conv2D(64, (3, 3), activation='relu', padding='same')
        self.bn2 = layers.BatchNormalization()
        self.pool2 = layers.MaxPooling2D((2, 2))
        self.dropout2 = layers.Dropout(0.25)
        
        self.conv3 = layers.Conv2D(128, (3, 3), activation='relu', padding='same')
        self.bn3 = layers.BatchNormalization()
        
        # Global pooling and dense layers
        self.global_pool = layers.GlobalAveragePooling2D()
        self.dense1 = layers.Dense(256, activation='relu')
        self.dropout3 = layers.Dropout(0.3)
        self.dense2 = layers.Dense(embedding_dim, activation='relu')
        
    def call(self, x, training=False):
        # x shape: (batch, height, width, channels)
        x = self.conv1(x)
        x = self.bn1(x, training=training)
        x = self.pool1(x)
        x = self.dropout1(x, training=training)
        
        x = self.conv2(x)
        x = self.bn2(x, training=training)
        x = self.pool2(x)
        x = self.dropout2(x, training=training)
        
        x = self.conv3(x)
        x = self.bn3(x, training=training)
        
        x = self.global_pool(x)
        x = self.dense1(x)
        x = self.dropout3(x, training=training)
        x = self.dense2(x)
        
        return x  # (batch, embedding_dim)


class TemporalEncoder(keras.Model):
    """
    LSTM-based temporal feature extractor.
    Processes sequence of spatial embeddings to capture temporal patterns.
    """
    
    def __init__(self, embedding_dim=128, lstm_units=64):
        super(TemporalEncoder, self).__init__()
        
        self.lstm = layers.Bidirectional(
            layers.LSTM(lstm_units, return_sequences=False, dropout=0.2)
        )
        self.dense = layers.Dense(embedding_dim, activation='relu')
        
    def call(self, x, training=False):
        # x shape: (batch, time, spatial_embedding_dim)
        x = self.lstm(x, training=training)
        x = self.dense(x)
        return x  # (batch, embedding_dim)


class StressDetectionModel:
    """
    Complete stress detection pipeline with spatial-temporal encoding,
    clustering, and anomaly detection.
    """
    
    def __init__(self, patch_size=16, num_bands=8, num_timestamps=10,
                 spatial_embedding_dim=128, temporal_embedding_dim=128):
        self.patch_size = patch_size
        self.num_bands = num_bands
        self.num_timestamps = num_timestamps
        self.spatial_embedding_dim = spatial_embedding_dim
        self.temporal_embedding_dim = temporal_embedding_dim
        
        # Build encoders
        self.spatial_encoder = SpatialEncoder(embedding_dim=spatial_embedding_dim)
        self.temporal_encoder = TemporalEncoder(
            embedding_dim=temporal_embedding_dim,
            lstm_units=64
        )
        
        # Build spatial encoder input
        self.spatial_encoder.build((None, patch_size, patch_size, num_bands))
        
        # Clustering and anomaly detection (fitted during inference)
        self.kmeans = None
        self.anomaly_detector = None
        self.scaler = StandardScaler()
        
    def encode_spatial_features(self, patches: np.ndarray) -> np.ndarray:
        """
        Extract spatial features from all patches and timestamps.
        
        Args:
            patches: Array of shape (num_patches, time, height, width, bands)
            
        Returns:
            spatial_embeddings: Array of shape (num_patches, time, spatial_embedding_dim)
        """
        num_patches, time, height, width, bands = patches.shape
        
        # Reshape to process all patches and timestamps together
        # (num_patches * time, height, width, bands)
        reshaped = patches.reshape(-1, height, width, bands)
        
        # Extract spatial features
        spatial_features = self.spatial_encoder(reshaped, training=False).numpy()
        
        # Reshape back to (num_patches, time, embedding_dim)
        spatial_embeddings = spatial_features.reshape(
            num_patches, time, self.spatial_embedding_dim
        )
        
        return spatial_embeddings
    
    def encode_temporal_features(self, spatial_embeddings: np.ndarray) -> np.ndarray:
        """
        Extract temporal features from spatial embeddings.
        
        Args:
            spatial_embeddings: Array of shape (num_patches, time, spatial_embedding_dim)
            
        Returns:
            temporal_embeddings: Array of shape (num_patches, temporal_embedding_dim)
        """
        temporal_embeddings = self.temporal_encoder(
            spatial_embeddings, training=False
        ).numpy()
        
        return temporal_embeddings
    
    def cluster_stress_patterns(self, embeddings: np.ndarray, n_clusters=4) -> Tuple[np.ndarray, np.ndarray]:
        """
        Cluster embeddings into stress categories and compute stress scores.
        
        Args:
            embeddings: Array of shape (num_patches, embedding_dim)
            n_clusters: Number of clusters (4: high, moderate, low, noise)
            
        Returns:
            cluster_labels: Cluster assignment for each patch
            stress_scores: Normalized stress scores in [0, 1]
        """
        # Standardize embeddings
        embeddings_scaled = self.scaler.fit_transform(embeddings)
        
        # K-Means clustering
        self.kmeans = KMeans(n_clusters=n_clusters, random_state=42, n_init=10)
        cluster_labels = self.kmeans.fit_predict(embeddings_scaled)
        
        # Compute stress scores based on distance to cluster centers
        distances = self.kmeans.transform(embeddings_scaled)
        
        # For each patch, compute stress score as weighted distance to all clusters
        # Normalize to [0, 1] range
        stress_scores = np.min(distances, axis=1)  # Distance to nearest cluster
        stress_scores = 1 - (stress_scores - stress_scores.min()) / (stress_scores.max() - stress_scores.min() + 1e-10)
        
        # Alternative: Use cluster centers to assign stress levels
        # Identify which cluster represents highest stress (largest distance from origin)
        cluster_stress_levels = np.linalg.norm(self.kmeans.cluster_centers_, axis=1)
        cluster_stress_levels = (cluster_stress_levels - cluster_stress_levels.min()) / \
                               (cluster_stress_levels.max() - cluster_stress_levels.min() + 1e-10)
        
        # Assign stress score based on cluster membership
        stress_scores = cluster_stress_levels[cluster_labels]
        
        return cluster_labels, stress_scores
    
    def detect_anomalies(self, embeddings: np.ndarray, contamination=0.1) -> Tuple[np.ndarray, np.ndarray]:
        """
        Detect anomalous stress patterns using Isolation Forest.
        
        Args:
            embeddings: Array of shape (num_patches, embedding_dim)
            contamination: Expected proportion of anomalies
            
        Returns:
            anomaly_labels: 1 for normal, -1 for anomaly
            anomaly_scores: Anomaly scores (lower = more anomalous)
        """
        self.anomaly_detector = IsolationForest(
            contamination=contamination,
            random_state=42
        )
        anomaly_labels = self.anomaly_detector.fit_predict(embeddings)
        anomaly_scores = self.anomaly_detector.score_samples(embeddings)
        
        return anomaly_labels, anomaly_scores
    
    def predict(self, patches: np.ndarray, n_clusters=4, contamination=0.1) -> Dict:
        """
        Complete stress detection pipeline.
        
        Args:
            patches: Array of shape (num_patches, time, height, width, bands)
            n_clusters: Number of stress clusters
            contamination: Expected proportion of anomalies
            
        Returns:
            results: Dictionary with all predictions and embeddings
        """
        # Step 1: Spatial encoding
        spatial_embeddings = self.encode_spatial_features(patches)
        
        # Step 2: Temporal encoding
        temporal_embeddings = self.encode_temporal_features(spatial_embeddings)
        
        # Step 3: Clustering
        cluster_labels, stress_scores = self.cluster_stress_patterns(
            temporal_embeddings, n_clusters=n_clusters
        )
        
        # Step 4: Anomaly detection
        anomaly_labels, anomaly_scores = self.detect_anomalies(temporal_embeddings, contamination=contamination)
        
        return {
            'spatial_embeddings': spatial_embeddings,
            'temporal_embeddings': temporal_embeddings,
            'cluster_labels': cluster_labels,
            'stress_scores': stress_scores,
            'anomaly_labels': anomaly_labels,
            'anomaly_scores': anomaly_scores,
            'cluster_centers': self.kmeans.cluster_centers_,
            'n_clusters': n_clusters
        }


def get_stress_category(stress_score: float) -> str:
    """Convert stress score to category label."""
    if stress_score < 0.25:
        return "Low Stress"
    elif stress_score < 0.5:
        return "Moderate Stress"
    elif stress_score < 0.75:
        return "High Stress"
    else:
        return "Severe Stress"


def find_optimal_clusters(embeddings: np.ndarray, 
                         min_clusters: int = 2, 
                         max_clusters: int = 10) -> Tuple[int, Dict]:
    """
    Find optimal number of clusters using elbow method and silhouette score.
    
    Args:
        embeddings: Array of shape (num_samples, embedding_dim)
        min_clusters: Minimum number of clusters to test
        max_clusters: Maximum number of clusters to test
        
    Returns:
        optimal_k: Optimal number of clusters
        metrics: Dictionary with inertia and silhouette scores
    """
    print("\nFinding optimal number of clusters...")
    
    scaler = StandardScaler()
    embeddings_scaled = scaler.fit_transform(embeddings)
    
    inertias = []
    silhouette_scores = []
    k_range = range(min_clusters, max_clusters + 1)
    
    for k in k_range:
        kmeans = KMeans(n_clusters=k, random_state=42, n_init=10)
        labels = kmeans.fit_predict(embeddings_scaled)
        
        inertias.append(kmeans.inertia_)
        
        # Calculate silhouette score (higher is better)
        if k > 1:
            sil_score = silhouette_score(embeddings_scaled, labels)
            silhouette_scores.append(sil_score)
        else:
            silhouette_scores.append(0)
        
        print(f"  k={k}: Inertia={kmeans.inertia_:.2f}, Silhouette={silhouette_scores[-1]:.3f}")
    
    # Find elbow using rate of change
    inertia_diffs = np.diff(inertias)
    inertia_diffs_2 = np.diff(inertia_diffs)
    
    # Optimal k is where second derivative is maximum (elbow point)
    elbow_k = min_clusters + np.argmax(np.abs(inertia_diffs_2)) + 1
    
    # Also consider silhouette score
    best_silhouette_k = min_clusters + np.argmax(silhouette_scores)
    
    # Use silhouette score as primary metric, elbow as secondary
    optimal_k = best_silhouette_k
    
    print(f"\n[OK] Optimal clusters: {optimal_k} (Elbow: {elbow_k}, Best Silhouette: {best_silhouette_k})")
    
    metrics = {
        'k_range': list(k_range),
        'inertias': inertias,
        'silhouette_scores': silhouette_scores,
        'optimal_k': optimal_k,
        'elbow_k': elbow_k,
        'best_silhouette_k': best_silhouette_k
    }
    
    return optimal_k, metrics


def prepare_llm_context(results: Dict, 
                       patch_coords: List,
                       patches: np.ndarray,
                       metadata: Dict) -> Dict:
    """
    Prepare comprehensive context for LLM including cluster statistics and anomaly information.
    
    Args:
        results: Dictionary from model.predict()
        patch_coords: List of (h, w) coordinates for each patch
        patches: Original patches array
        metadata: Preprocessing metadata
        
    Returns:
        context: Dictionary with cluster-wise and anomaly statistics
    """
    cluster_labels = results['cluster_labels']
    stress_scores = results['stress_scores']
    anomaly_labels = results['anomaly_labels']
    temporal_embeddings = results['temporal_embeddings']
    
    # Get anomaly scores (distance from decision boundary)
    anomaly_scores = results.get('anomaly_scores', 
                                 results['anomaly_labels'].astype(float))
    
    # Cluster-wise statistics
    cluster_stats = []
    for cluster_id in range(results['n_clusters']):
        cluster_mask = cluster_labels == cluster_id
        cluster_patches = patches[cluster_mask]
        cluster_stress = stress_scores[cluster_mask]
        cluster_embeddings = temporal_embeddings[cluster_mask]
        
        # Calculate statistics for this cluster
        stats = {
            'cluster_id': int(cluster_id),
            'num_patches': int(np.sum(cluster_mask)),
            'percentage': float(100 * np.sum(cluster_mask) / len(cluster_labels)),
            'stress_score': {
                'mean': float(cluster_stress.mean()),
                'std': float(cluster_stress.std()),
                'min': float(cluster_stress.min()),
                'max': float(cluster_stress.max())
            },
            'embedding_stats': {
                'mean_norm': float(np.linalg.norm(cluster_embeddings.mean(axis=0))),
                'std_norm': float(np.linalg.norm(cluster_embeddings.std(axis=0)))
            },
            'band_statistics': {}
        }
        
        # Calculate per-band statistics for this cluster
        for band_idx, band_name in enumerate(metadata['selected_bands']):
            band_data = cluster_patches[:, :, :, :, band_idx]  # (patches, time, h, w)
            stats['band_statistics'][band_name] = {
                'mean': float(np.nanmean(band_data)),
                'std': float(np.nanstd(band_data)),
                'min': float(np.nanmin(band_data)),
                'max': float(np.nanmax(band_data))
            }
        
        cluster_stats.append(stats)
        
        # Calculate temporal trends for this cluster
        # Shape: (num_patches, time, h, w, bands) -> (time, bands)
        if cluster_patches.shape[0] > 0:
            cluster_time_series = np.nanmean(cluster_patches, axis=(0, 2, 3))
            
            stats['temporal_trends'] = {}
            for band_idx, band_name in enumerate(metadata['selected_bands']):
                series = cluster_time_series[:, band_idx]
                if len(series) > 1:
                    change = float(series[-1] - series[0])
                    trend_direction = "stable"
                    if change > 0.05: trend_direction = "increasing"
                    elif change < -0.05: trend_direction = "decreasing"
                    
                    stats['temporal_trends'][band_name] = {
                        'change': change,
                        'trend_direction': trend_direction,
                        'latest_value': float(series[-1]),
                        'earliest_value': float(series[0])
                    }
    
    # Anomaly information
    anomaly_mask = anomaly_labels == -1
    anomaly_indices = np.where(anomaly_mask)[0]
    
    anomaly_info = {
        'total_anomalies': int(np.sum(anomaly_mask)),
        'anomaly_percentage': float(100 * np.sum(anomaly_mask) / len(anomaly_labels)),
        'anomaly_patches': []
    }
    
    # Detailed info for each anomaly patch
    for idx in anomaly_indices[:20]:  # Limit to first 20 anomalies
        patch_info = {
            'patch_id': int(idx),
            'coordinates': patch_coords[idx],
            'stress_score': float(stress_scores[idx]),
            'stress_category': get_stress_category(stress_scores[idx]),
            'cluster_id': int(cluster_labels[idx]),
            'anomaly_score': float(anomaly_scores[idx]) if hasattr(anomaly_scores, '__getitem__') else -1.0,
            'embedding_norm': float(np.linalg.norm(temporal_embeddings[idx]))
        }
        anomaly_info['anomaly_patches'].append(patch_info)
    
    # Overall field statistics
    field_stats = {
        'total_patches': len(cluster_labels),
        'patch_size': metadata['patch_size'],
        'num_bands': metadata['num_bands'],
        'selected_bands': metadata['selected_bands'],
        'overall_stress': {
            'mean': float(stress_scores.mean()),
            'std': float(stress_scores.std()),
            'min': float(stress_scores.min()),
            'max': float(stress_scores.max())
        },
        'stress_distribution': {
            'low': int(np.sum(stress_scores < 0.25)),
            'moderate': int(np.sum((stress_scores >= 0.25) & (stress_scores < 0.5))),
            'high': int(np.sum((stress_scores >= 0.5) & (stress_scores < 0.75))),
            'severe': int(np.sum(stress_scores >= 0.75))
        }
    }
    
    context = {
        'field_statistics': field_stats,
        'cluster_statistics': cluster_stats,
        'anomaly_information': anomaly_info
    }
    
    return context

