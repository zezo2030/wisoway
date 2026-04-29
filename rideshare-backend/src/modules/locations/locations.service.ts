import {
  Injectable,
  BadRequestException,
  InternalServerErrorException,
  Logger,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import axios from 'axios';

@Injectable()
export class LocationsService {
  private readonly logger = new Logger(LocationsService.name);
  private readonly googleMapsApiKey: string;
  private readonly googleMapsBaseUrl = 'https://maps.googleapis.com/maps/api';
  private readonly osrmBaseUrl = 'https://router.project-osrm.org';

  constructor(private configService: ConfigService) {
    this.googleMapsApiKey = this.configService.get<string>(
      'GOOGLE_MAPS_API_KEY',
      '',
    );
  }

  async geocode(address: string) {
    try {
      const response = await axios.get(
        `${this.googleMapsBaseUrl}/geocode/json`,
        {
          params: {
            address,
            key: this.googleMapsApiKey,
          },
        },
      );

      if (response.data.status !== 'OK') {
        throw new BadRequestException('Address not found');
      }

      const result = response.data.results[0];
      return {
        latitude: result.geometry.location.lat,
        longitude: result.geometry.location.lng,
        formattedAddress: result.formatted_address,
        placeId: result.place_id,
      };
    } catch (error) {
      if (error instanceof BadRequestException) {
        throw error;
      }
      throw new BadRequestException('Failed to geocode address');
    }
  }

  async reverseGeocode(latitude: number, longitude: number) {
    try {
      const response = await axios.get(
        `${this.googleMapsBaseUrl}/geocode/json`,
        {
          params: {
            latlng: `${latitude},${longitude}`,
            key: this.googleMapsApiKey,
          },
        },
      );

      if (response.data.status !== 'OK') {
        throw new BadRequestException('Location not found');
      }

      const result = response.data.results[0];
      const addressComponents = result.address_components;

      const getAddressComponent = (types: string[]) =>
        addressComponents.find((component: any) =>
          types.every((type) => component.types.includes(type)),
        )?.long_name || '';

      return {
        address: result.formatted_address,
        city: getAddressComponent(['locality', 'administrative_area_level_2']),
        country: getAddressComponent(['country']),
        countryCode: getAddressComponent(['country']),
      };
    } catch (error) {
      if (error instanceof BadRequestException) {
        throw error;
      }
      throw new BadRequestException('Failed to reverse geocode location');
    }
  }

  async getDistance(
    fromLatitude: number,
    fromLongitude: number,
    toLatitude: number,
    toLongitude: number,
  ) {
    try {
      const response = await axios.get(
        `${this.googleMapsBaseUrl}/distancematrix/json`,
        {
          params: {
            origins: `${fromLatitude},${fromLongitude}`,
            destinations: `${toLatitude},${toLongitude}`,
            key: this.googleMapsApiKey,
          },
        },
      );

      if (response.data.status !== 'OK') {
        throw new BadRequestException('Failed to calculate distance');
      }

      const element = response.data.rows[0].elements[0];
      if (element.status !== 'OK') {
        throw new BadRequestException('Failed to calculate distance');
      }

      return {
        distanceKm: element.distance.value / 1000,
        distanceText: element.distance.text,
        durationMinutes: Math.ceil(element.duration.value / 60),
        durationText: element.duration.text,
      };
    } catch (error) {
      if (error instanceof BadRequestException) {
        throw error;
      }
      throw new BadRequestException('Failed to calculate distance');
    }
  }

  async getRoute(
    fromLatitude: number,
    fromLongitude: number,
    toLatitude: number,
    toLongitude: number,
  ) {
    if (!this.googleMapsApiKey) {
      this.logger.warn(
        'Google Maps API key is not configured. Falling back to OSRM for route generation.',
      );
      return this.getRouteFromOsrm(
        fromLatitude,
        fromLongitude,
        toLatitude,
        toLongitude,
      );
    }

    try {
      const response = await axios.get(
        `${this.googleMapsBaseUrl}/directions/json`,
        {
          params: {
            origin: `${fromLatitude},${fromLongitude}`,
            destination: `${toLatitude},${toLongitude}`,
            key: this.googleMapsApiKey,
            language: 'ar',
          },
        },
      );

      if (response.data.status !== 'OK') {
        const providerStatus = response.data.status ?? 'UNKNOWN';
        const providerMessage =
          response.data.error_message ?? 'No error message';
        this.logger.warn(
          `Directions API failed with status=${providerStatus}, message=${providerMessage}. Falling back to OSRM.`,
        );
        return this.getRouteFromOsrm(
          fromLatitude,
          fromLongitude,
          toLatitude,
          toLongitude,
        );
      }

      const route = response.data.routes?.[0];
      const leg = route?.legs?.[0];
      const overviewPolyline = route?.overview_polyline?.points;

      if (!route || !leg || !overviewPolyline) {
        this.logger.warn(
          'Directions API returned OK without a usable route payload. Falling back to OSRM.',
        );
        return this.getRouteFromOsrm(
          fromLatitude,
          fromLongitude,
          toLatitude,
          toLongitude,
        );
      }

      return {
        overviewPolyline,
        distanceText: leg.distance?.text ?? '',
        durationText: leg.duration?.text ?? '',
      };
    } catch (error) {
      if (error instanceof BadRequestException) {
        throw error;
      }

      this.logger.error(
        'Unexpected Google Directions error. Falling back to OSRM.',
        error as Error,
      );
      return this.getRouteFromOsrm(
        fromLatitude,
        fromLongitude,
        toLatitude,
        toLongitude,
      );
    }
  }

  private async getRouteFromOsrm(
    fromLatitude: number,
    fromLongitude: number,
    toLatitude: number,
    toLongitude: number,
  ) {
    try {
      const response = await axios.get(
        `${this.osrmBaseUrl}/route/v1/driving/${fromLongitude},${fromLatitude};${toLongitude},${toLatitude}`,
        {
          params: {
            overview: 'full',
            geometries: 'polyline',
            steps: false,
          },
        },
      );

      if (response.data.code !== 'Ok') {
        const code = response.data.code ?? 'UNKNOWN';
        const message = response.data.message ?? 'No error message';
        throw new BadRequestException(
          `Failed to load route: OSRM ${code} - ${message}`,
        );
      }

      const route = response.data.routes?.[0];
      if (!route?.geometry) {
        throw new BadRequestException(
          'Failed to load route: OSRM empty route payload',
        );
      }

      return {
        overviewPolyline: route.geometry,
        distanceText: this.formatDistanceKm(route.distance),
        durationText: this.formatDurationMinutes(route.duration),
      };
    } catch (error) {
      if (error instanceof BadRequestException) {
        throw error;
      }

      this.logger.error('OSRM route fallback failed', error as Error);
      throw new BadRequestException('Failed to load route');
    }
  }

  private formatDistanceKm(distanceMeters?: number) {
    if (typeof distanceMeters !== 'number') return '';

    const distanceKm = distanceMeters / 1000;
    return distanceKm >= 10
      ? `${distanceKm.toFixed(0)} كم`
      : `${distanceKm.toFixed(1)} كم`;
  }

  private formatDurationMinutes(durationSeconds?: number) {
    if (typeof durationSeconds !== 'number') return '';

    const minutes = Math.max(1, Math.round(durationSeconds / 60));
    if (minutes < 60) {
      return `${minutes} دقيقة`;
    }

    const hours = Math.floor(minutes / 60);
    const remainingMinutes = minutes % 60;
    if (remainingMinutes == 0) {
      return `${hours} ساعة`;
    }

    return `${hours} ساعة ${remainingMinutes} دقيقة`;
  }
}
