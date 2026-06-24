declare module 'zipcodes' {
  export interface ZipLookup {
    zip: string;
    latitude: number;
    longitude: number;
    city: string;
    state: string;
    country: string;
  }

  export function lookup(zip: string): ZipLookup | undefined;

  const zipcodes: {
    lookup: typeof lookup;
  };

  export default zipcodes;
}
