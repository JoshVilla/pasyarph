// Overnight towns for multi-day loops: places riders actually stay, with
// lodging and fuel, spread over each island. Multi-day loops route through
// a ring of these (see multiday.ts). Coordinates are town centers.
//
// island: towns are only joined on the same landmass (the car profile has
// no ferries). Leyte and Samar are joined by the San Juanico Bridge.

export interface Town {
  name: string;
  lng: number;
  lat: number;
  island: string;
}

const t = (name: string, lat: number, lng: number, island: string): Town => ({
  name,
  lat,
  lng,
  island,
});

export const TOWNS: Town[] = [
  // Luzon: north
  t('Pagudpud', 18.5617, 120.7876, 'luzon'),
  t('Laoag', 18.1978, 120.5936, 'luzon'),
  t('Vigan', 17.5747, 120.3869, 'luzon'),
  t('Candon', 17.1948, 120.4515, 'luzon'),
  t('San Fernando, La Union', 16.6159, 120.3166, 'luzon'),
  t('Baguio', 16.4023, 120.596, 'luzon'),
  t('Sagada', 17.0839, 120.9006, 'luzon'),
  t('Bontoc', 17.089, 120.9771, 'luzon'),
  t('Banaue', 16.9134, 121.0573, 'luzon'),
  t('Tabuk', 17.4189, 121.4443, 'luzon'),
  t('Aparri', 18.3565, 121.6403, 'luzon'),
  t('Tuguegarao', 17.6132, 121.727, 'luzon'),
  t('Ilagan', 17.1485, 121.8892, 'luzon'),
  t('Santiago, Isabela', 16.6889, 121.5486, 'luzon'),
  t('Bayombong', 16.4844, 121.1427, 'luzon'),
  // Luzon: central
  t('Alaminos', 16.1554, 119.981, 'luzon'),
  t('Dagupan', 16.0433, 120.3333, 'luzon'),
  t('Baler', 15.7586, 121.5623, 'luzon'),
  t('Cabanatuan', 15.4865, 120.9667, 'luzon'),
  t('Tarlac City', 15.4802, 120.5979, 'luzon'),
  t('Iba', 15.3276, 119.9783, 'luzon'),
  t('Olongapo', 14.8386, 120.2842, 'luzon'),
  t('San Fernando, Pampanga', 15.0286, 120.6898, 'luzon'),
  t('Manila', 14.5995, 120.9842, 'luzon'),
  t('Infanta', 14.7425, 121.6497, 'luzon'),
  // Luzon: south
  t('Tagaytay', 14.1153, 120.9621, 'luzon'),
  t('Batangas City', 13.7565, 121.0583, 'luzon'),
  t('Lucena', 13.9373, 121.617, 'luzon'),
  t('Daet', 14.1122, 122.9553, 'luzon'),
  t('Naga', 13.6218, 123.1948, 'luzon'),
  t('Legazpi', 13.1391, 123.7438, 'luzon'),
  t('Sorsogon', 12.9742, 124.0058, 'luzon'),
  // Mindoro
  t('Puerto Galera', 13.5033, 120.9545, 'mindoro'),
  t('Calapan', 13.4113, 121.1803, 'mindoro'),
  t('Roxas, Oriental Mindoro', 12.5862, 121.5223, 'mindoro'),
  t('San Jose, Occidental Mindoro', 12.3528, 121.0672, 'mindoro'),
  t('Sablayan', 12.8366, 120.7756, 'mindoro'),
  // Palawan
  t('El Nido', 11.1784, 119.393, 'palawan'),
  t('Taytay', 10.8255, 119.5181, 'palawan'),
  t('Roxas, Palawan', 10.3195, 119.3424, 'palawan'),
  t('Puerto Princesa', 9.7392, 118.7353, 'palawan'),
  t('Brooke\'s Point', 8.7834, 117.834, 'palawan'),
  // Panay
  t('Kalibo', 11.7065, 122.3683, 'panay'),
  t('Roxas City', 11.5853, 122.7511, 'panay'),
  t('Iloilo City', 10.7202, 122.5621, 'panay'),
  t('San Jose de Buenavista', 10.7449, 121.9416, 'panay'),
  t('Caticlan', 11.9298, 121.9531, 'panay'),
  // Negros
  t('Bacolod', 10.6765, 122.9509, 'negros'),
  t('San Carlos, Negros', 10.4929, 123.4093, 'negros'),
  t('Sipalay', 9.7516, 122.4048, 'negros'),
  t('Dumaguete', 9.3068, 123.3054, 'negros'),
  t('Cadiz', 10.9536, 123.2995, 'negros'),
  // Cebu
  t('Cebu City', 10.3157, 123.8854, 'cebu'),
  t('Bogo', 11.0516, 124.0056, 'cebu'),
  t('Moalboal', 9.9504, 123.3976, 'cebu'),
  t('Oslob', 9.4629, 123.3861, 'cebu'),
  t('Toledo', 10.3773, 123.6386, 'cebu'),
  // Bohol
  t('Tagbilaran', 9.65, 123.85, 'bohol'),
  t('Anda', 9.7445, 124.5761, 'bohol'),
  t('Carmen, Bohol', 9.8221, 124.1985, 'bohol'),
  // Leyte and Samar
  t('Tacloban', 11.2443, 125.0039, 'leyte'),
  t('Ormoc', 11.0059, 124.6075, 'leyte'),
  t('Maasin', 10.1335, 124.8442, 'leyte'),
  t('Catbalogan', 11.7753, 124.8861, 'leyte'),
  t('Borongan', 11.6077, 125.4319, 'leyte'),
  t('Catarman', 12.4994, 124.6377, 'leyte'),
  // Mindanao
  t('Surigao City', 9.7843, 125.4888, 'mindanao'),
  t('Butuan', 8.9475, 125.5406, 'mindanao'),
  t('Tandag', 9.0783, 126.1986, 'mindanao'),
  t('Cagayan de Oro', 8.4542, 124.6319, 'mindanao'),
  t('Iligan', 8.228, 124.2452, 'mindanao'),
  t('Malaybalay', 8.1575, 125.1278, 'mindanao'),
  t('Ozamiz', 8.1481, 123.8405, 'mindanao'),
  t('Dipolog', 8.5872, 123.3409, 'mindanao'),
  t('Pagadian', 7.8257, 123.437, 'mindanao'),
  t('Zamboanga City', 6.9214, 122.079, 'mindanao'),
  t('Davao City', 7.1907, 125.4553, 'mindanao'),
  t('Mati', 6.9551, 126.2179, 'mindanao'),
  t('General Santos', 6.1164, 125.1716, 'mindanao'),
  t('Koronadal', 6.5031, 124.8469, 'mindanao'),
  t('Kidapawan', 7.0083, 125.0894, 'mindanao'),
  t('Bislig', 8.2149, 126.3216, 'mindanao'),
];
