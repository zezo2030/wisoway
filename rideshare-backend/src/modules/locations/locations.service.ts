import { Injectable, BadRequestException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import axios from 'axios';

@Injectable()
export class LocationsService {
  private readonly googleMapsApiKey: string;
  private readonly googleMapsBaseUrl = 'https://maps.googleapis.com/maps/api';

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
}
