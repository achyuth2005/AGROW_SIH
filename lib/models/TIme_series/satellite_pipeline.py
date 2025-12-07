"""
Satellite Data Pipeline
Fetches both Sentinel-1 (SAR) and Sentinel-2 (Optical) data for a given polygon.
Outputs two separate CSV files: `sar_data.csv` and `sentinel2_data.csv`.
"""

import os
import datetime
import numpy as np
import pandas as pd
from shapely.geometry import Polygon
from dotenv import load_dotenv

from sentinelhub import (
    SHConfig, 
    SentinelHubRequest,
    SentinelHubCatalog,
    DataCollection, 
    MimeType, 
    BBox, 
    CRS,
    bbox_to_dimensions,
    Geometry
)

# Load environment variables
load_dotenv()

class SatelliteFetcher:
    """
    A class to fetch and process satellite data (SAR and Optical) for a specific area of interest.
    """
    
    def __init__(self, polygon_coords):
        """
        Initialize the fetcher.
        
        Args:
            polygon_coords (list): List of (lon, lat) tuples defining the polygon.
        """
        self.polygon_coords = polygon_coords
        self.start_date = '2020-01-01'
        self.end_date = datetime.date.today().strftime('%Y-%m-%d')
        
        # Configuration
        self.resolution = 10
        self.max_cloud_cover = 20.0
        
        # Setup Sentinel Hub
        self.config = self._setup_config()
        self.geometry, self.bbox, self.size = self._setup_geometry()
        
    def _setup_config(self):
        """Configure Sentinel Hub credentials."""
        config = SHConfig()
        config.sh_client_id = os.environ.get('SH_CLIENT_ID')
        config.sh_client_secret = os.environ.get('SH_CLIENT_SECRET')
        
        if not config.sh_client_id:
            config.sh_client_id = "sh-4c23abb9-6263-4a2c-bdba-a4ff6b84bdfb"
        if not config.sh_client_secret:
            config.sh_client_secret = "iZ4gexrfiWQpopHAGYlBeEMj9J8DAZtD"

        config.sh_base_url = 'https://sh.dataspace.copernicus.eu'
        config.sh_token_url = 'https://identity.dataspace.copernicus.eu/auth/realms/CDSE/protocol/openid-connect/token'
        config.save("cdse")
        
        return config

    def _setup_geometry(self):
        """Setup geometry, bbox, and size from polygon coordinates."""
        shapely_poly = Polygon(self.polygon_coords)
        geometry = Geometry(shapely_poly, crs=CRS.WGS84)
        bbox = geometry.bbox
        size = bbox_to_dimensions(bbox, resolution=self.resolution)
        
        print(f"AOI Setup:")
        print(f"  Polygon: {self.polygon_coords}")
        print(f"  BBox: {bbox}")
        print(f"  Size: {size}")
        print(f"  Time Range: {self.start_date} to {self.end_date}")
        
        return geometry, bbox, size

    def fetch_sar_data(self, output_csv='sar_data.csv'):
        """
        Fetch Sentinel-1 SAR data (VV, VH) and save to CSV.
        """
        print("\n" + "="*40)
        print("FETCHING SENTINEL-1 SAR DATA")
        print("="*40)
        
        S1 = DataCollection.define(
            name="SENTINEL1_IW_CDSE",
            api_id="sentinel-1-grd",
            service_url="https://sh.dataspace.copernicus.eu"
        )
        
        evalscript = """
        //VERSION=3
        function setup() {
          return {
            input: ["VV", "VH", "dataMask"],
            output: [
              { id: "VV", bands: 1, sampleType: "FLOAT32" },
              { id: "VH", bands: 1, sampleType: "FLOAT32" }
            ]
          };
        }
        
        function evaluatePixel(sample) {
          let vv_db = (sample.VV > 0) ? 10 * Math.log(sample.VV) / Math.LN10 : -9999;
          let vh_db = (sample.VH > 0) ? 10 * Math.log(sample.VH) / Math.LN10 : -9999;
          return { VV: [vv_db], VH: [vh_db] };
        }
        """
        
        print("🔍 Searching catalog...")
        catalog = SentinelHubCatalog(config=self.config)
        results = catalog.search(
            collection=S1,
            geometry=self.geometry,
            time=(self.start_date, self.end_date),
            filter="sar:instrument_mode = 'IW'"
        )
        
        scenes = list(results)
        dates = sorted(list(set([scene['properties']['datetime'].split('T')[0] for scene in scenes])))
        print(f"✓ Found {len(dates)} unique dates.")
        
        all_records = []
        
        print("📥 Downloading and Processing...")
        for date_str in dates:
            dt = datetime.datetime.strptime(date_str, "%Y-%m-%d")
            next_day = (dt + datetime.timedelta(days=1)).strftime("%Y-%m-%d")
            
            request = SentinelHubRequest(
                evalscript=evalscript,
                input_data=[
                    SentinelHubRequest.input_data(
                        data_collection=S1,
                        time_interval=(date_str, next_day),
                        mosaicking_order="leastRecent",
                        other_args={"processing": {"backCoeff": "GAMMA0_TERRAIN", "orthorectify": True}}
                    )
                ],
                responses=[
                    SentinelHubRequest.output_response('VV', MimeType.TIFF),
                    SentinelHubRequest.output_response('VH', MimeType.TIFF)
                ],
                geometry=self.geometry,
                bbox=self.bbox,
                size=self.size,
                config=self.config
            )

            try:
                data = request.get_data()
                if data and len(data) > 0:
                    data_dict = data[0]
                    if 'VV.tif' in data_dict and 'VH.tif' in data_dict:
                        vv_arr = data_dict['VV.tif']
                        vh_arr = data_dict['VH.tif']
                        
                        valid_mask = (vv_arr > -9999) & (vh_arr > -9999)
                        
                        if np.any(valid_mask):
                            vv_mean = np.mean(vv_arr[valid_mask])
                            vh_mean = np.mean(vh_arr[valid_mask])
                            
                            all_records.append({
                                'ds': date_str,
                                'VV_mean_dB': round(vv_mean, 4),
                                'VH_mean_dB': round(vh_mean, 4)
                            })
                            print(f"  ✓ {date_str}: VV={vv_mean:.2f}, VH={vh_mean:.2f}")
                        else:
                            print(f"  ⚠ {date_str}: No valid pixels")
            except Exception as e:
                print(f"  ❌ Error {date_str}: {e}")
                
        df = pd.DataFrame(all_records)
        if not df.empty:
            df = df.sort_values('ds').reset_index(drop=True)
            df.to_csv(output_csv, index=False)
            print(f"\n💾 Saved SAR data to: {output_csv}")
        else:
            print("\n⚠ No SAR data fetched.")

    def fetch_sentinel2_data(self, output_csv='sentinel2_data.csv'):
        """
        Fetch Sentinel-2 L2A data (Bands + SCL) and save to CSV.
        """
        print("\n" + "="*40)
        print("FETCHING SENTINEL-2 OPTICAL DATA")
        print("="*40)
        
        S2 = DataCollection.define(
            name="SENTINEL2_L2A_CDSE",
            api_id="sentinel-2-l2a",
            service_url="https://sh.dataspace.copernicus.eu",
            collection_type="Sentinel-2",
            is_timeless=False
        )
        
        evalscript = """
        //VERSION=3
        function setup() {
            return {
                input: [{
                    bands: ["B01", "B02", "B03", "B04", "B05", "B06", "B07", "B08", "B8A", "B09", "B11", "B12", "SCL", "dataMask"],
                    units: "DN"
                }],
                output: {
                    bands: 13,
                    sampleType: "FLOAT32"
                }
            };
        }
    
        function evaluatePixel(sample) {
            if (sample.dataMask == 0) {
                return [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
            }
            return [
                sample.B01 / 10000, sample.B02 / 10000, sample.B03 / 10000, sample.B04 / 10000,
                sample.B05 / 10000, sample.B06 / 10000, sample.B07 / 10000, sample.B08 / 10000,
                sample.B8A / 10000, sample.B09 / 10000, sample.B11 / 10000, sample.B12 / 10000,
                sample.SCL
            ];
        }
        """
        
        print("🔍 Searching catalog...")
        catalog = SentinelHubCatalog(config=self.config)
        search_iterator = catalog.search(
            S2,
            geometry=self.geometry,
            time=(self.start_date, self.end_date),
            filter=f'eo:cloud_cover < {self.max_cloud_cover}'
        )
        
        dates = sorted(list(set([item['properties']['datetime'] for item in search_iterator])))
        print(f"✓ Found {len(dates)} available scenes.")
        
        results = []
        band_names = ["B01", "B02", "B03", "B04", "B05", "B06", "B07", "B08", "B8A", "B09", "B11", "B12"]
        
        print("📥 Downloading and Processing...")
        for i, date_str in enumerate(dates):
            request = SentinelHubRequest(
                evalscript=evalscript,
                input_data=[SentinelHubRequest.input_data(
                    data_collection=S2,
                    time_interval=(date_str, date_str)
                )],
                responses=[SentinelHubRequest.output_response('default', MimeType.TIFF)],
                geometry=self.geometry,
                bbox=self.bbox,
                size=self.size,
                config=self.config
            )
            
            try:
                data = request.get_data()[0]
                scl = data[:, :, 12]
                valid_mask = (scl != 0)
                
                if np.any(valid_mask):
                    means = {}
                    for b_idx, b_name in enumerate(band_names):
                        means[b_name] = np.mean(data[:, :, b_idx][valid_mask])
                    
                    means['ds'] = date_str.split('T')[0]
                    results.append(means)
                    print(f"  ✓ {date_str[:10]}")
                else:
                    print(f"  ⚠ {date_str[:10]} (No valid pixels)")
            except Exception as e:
                print(f"  ❌ Error {date_str[:10]}: {e}")

        df = pd.DataFrame(results)
        if not df.empty:
            cols = ['ds'] + [c for c in df.columns if c != 'ds']
            df = df[cols]
            df.to_csv(output_csv, index=False)
            print(f"\n💾 Saved Sentinel-2 data to: {output_csv}")
        else:
            print("\n⚠ No Sentinel-2 data fetched.")

    def run_all(self):
        """Run both pipelines."""
        self.fetch_sar_data()
        self.fetch_sentinel2_data()


if __name__ == "__main__":
    # Example Usage
    # PAU Experimental Farm, Punjab, India
    POLYGON = [
        (75.829, 30.229),
        (75.831, 30.229),
        (75.831, 30.231),
        (75.829, 30.231),
        (75.829, 30.229)
    ]
    
    # Initialize and Run
    fetcher = SatelliteFetcher(POLYGON)
    fetcher.run_all()
