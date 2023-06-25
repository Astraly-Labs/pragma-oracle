// // #[contract]
// // mod Library {
// //     use starknet::get_caller_address;
// //     use zeroable::Zeroable;
// //     use cmp::{max, min};
// //     use entry::contracts::entry::Entry;
// //     use option::OptionTrait;
// //     use array::{ArrayTrait, SpanTrait};
// //     use traits::Into;
// //     use traits::TryInto;
// //     use box::BoxTrait;
// //     use result::{ResultTrait, ResultTraitImpl};
// //     use entry::contracts::structs::{
// //         BaseEntry, SpotEntry, Currency, Pair, DataType, PragmaPricesResponse, Checkpoint,
// //         USD_CURRENCY_ID, SPOT, FUTURE, OPTION, PossibleEntryStorage, FutureEntry, OptionEntry,
// //         simpleDataType, SpotEntryStorage, FutureEntryStorage, AggregationMode, PossibleEntries,
// //         ArrayEntry
// //     };

// //     use oracle::business_logic::oracleInterface::IOracle;
// //     use pragma::bits_manipulation::bits_manipulation::{
// //         actual_set_element_at, actual_get_element_at
// //     };
// //     use pragma::time_series::convert::convert_via_usd;
// //     use admin::contracts::Admin::Admin;
// //     use serde::{Serde};
// //     use serde::deserialize_array_helper;
// //     use serde::serialize_array_helper;
// //     use starknet::{StorageAccess, StorageBaseAddress, SyscallResult};
// //     use starknet::{
// //         storage_read_syscall, storage_write_syscall, storage_address_from_base_and_offset,
// //         storage_access::storage_base_address_from_felt252
// //     };
// //     use starknet::{ContractAddress, Felt252TryIntoContractAddress};
// //     use starknet::{get_block_timestamp};
// //     use publisher_registry::contracts::publisher_registry::{
// //         IPublisherRegistryABIDispatcher, IPublisherRegistryABIDispatcherTrait
// //     };
// //     const BACKWARD_TIMESTAMP_BUFFER: u64 = 7800; // 2 hours and 10 minutes

// //     //Structure

//     struct Storage {
//         //oracle controller address storage, contractAddress
//         oracle_controller_address_storage: ContractAddress,
//         // oracle publisher registry address, ContractAddres
//         oracle_publisher_registry_address_storage: ContractAddress,
//         //oracle pair storage, legacy map between the pair_id and the pair in question (no need to specify the data type here).
//         oracle_pairs_storage: LegacyMap::<felt252, Pair>,
//         //oracle_pair_id_storage, legacy Map between (quote_currency_id, base_currency_id) and the pair_id
//         oracle_pair_id_storage: LegacyMap::<(felt252, felt252), felt252>,
//         //oracle_currencies_storage, legacy Map between (currency_id) and the currency
//         oracle_currencies_storage: LegacyMap::<felt252, Currency>,
//         //oralce_sources_storage, legacyMap between (pair_id ,(SPOT/FUTURES/OPTIONS), index, expiration_timestamp ) and the source
//         oracle_sources_storage: LegacyMap::<(felt252, felt252, u64, u64), felt252>,
//         //oracle_sources_len_storage, legacyMap between (pair_id ,(SPOT/FUTURES/OPTIONS), expiration_timestamp) and the len of the sources array
//         oracle_sources_len_storage: LegacyMap::<(felt252, felt252, u64), u64>,
//         //oracle_data_entry_storage, legacyMap between (pair_id, (SPOT/FUTURES/OPTIONS), source, expiration_timestamp (0 for SPOT))
//         oracle_data_entry_storage: LegacyMap::<(felt252, felt252, felt252, u64), u256>,
//         //oracle_checkpoints, legacyMap between, (pair_id, (SPOT/FUTURES/OPTIONS), index, expiration_timestamp (0 for SPOT)) asociated to a checkpoint
//         oracle_checkpoints: LegacyMap::<(felt252, felt252, u64, u64), Checkpoint>,
//         //oracle_checkpoint_index, legacyMap between (pair_id, (SPOT/FUTURES/OPTIONS), expiration_timestamp (0 for SPOT)) and the index of the last checkpoint
//         oracle_checkpoint_index: LegacyMap::<(felt252, felt252, u64), u64>,
//         oracle_sources_threshold_storage: u32,
//     }
//     impl SpanSerde<
//         T, impl TSerde: Serde<T>, impl TCopy: Copy<T>, impl TDrop: Drop<T>
//     > of Serde<Span<T>> {
//         fn serialize(self: @Span<T>, ref output: Array<felt252>) {
//             (*self).len().serialize(ref output);
//             serialize_array_helper(*self, ref output);
//         }
//         fn deserialize(ref serialized: Span<felt252>) -> Option<Span<T>> {
//             let length = *serialized.pop_front()?;
//             let mut arr = ArrayTrait::new();
//             Option::Some(deserialize_array_helper(ref serialized, arr, length)?.span())
//         }
//     }

// //     #[event]
// //     fn UpdatedPublisherRegistryAddress(
// //         old_publisher_registry_address: ContractAddress,
// //         new_publisher_registry_address: ContractAddress
// //     ) {}

// //     #[event]
// //     fn SubmittedSpotEntry(spot_entry: SpotEntry) {}

// //     #[event]
// //     fn SubmittedFutureEntry(future_entry: FutureEntry) {}

// //     #[event]
// //     fn SubmittedOptionEntry(option_entry: OptionEntry) {}

// //     #[event]
// //     fn SubmittedCurrency(currency: Currency) {}

// //     #[event]
// //     fn UpdatedCurrency(currency: Currency) {}

// //     #[event]
// //     fn SubmittedPair(pair: Pair) {}

// //     #[event]
// //     fn CheckpointSpotEntry(pair_id: felt252) {}

// //     #[event]
// //     fn CheckpointFutureEntry(pair_id: felt252, expiration_timestamp: u64) {}

// //     fn initializer(
// //         publisher_registry_address: ContractAddress, currencies: Span<Currency>, pairs: Span<Pair>
// //     ) {
// //         oracle_publisher_registry_address_storage::write(publisher_registry_address);
// //         _set_keys_currencies(currencies, 0);
// //         _set_keys_pairs(pairs);
// //     }

// //     //
// //     //Getters
// //     //

// //     fn get_decimals(data_type: DataType) -> u32 {
// //         let currency = match data_type {
// //             DataType::SpotEntry(pair_id) => {
// //                 let pair = oracle_pairs_storage::read(pair_id);
// //                 oracle_currencies_storage::read(pair.base_currency_id)
// //             },
// //             DataType::FutureEntry((
// //                 pair_id, expiration_timestamp
// //             )) => {
// //                 let pair = oracle_pairs_storage::read(pair_id);
// //                 oracle_currencies_storage::read(pair.base_currency_id)
// //             },
// //         // DataType::OptionEntry((pair_id, expiration_timestamp)) => {}
// //         };
// //         currency.decimals
// //     }

// //     fn get_data(
// //         data_type: DataType, aggregation_mode: AggregationMode, sources: Span<felt252>
// //     ) -> PragmaPricesResponse {
// //         let mut entries = ArrayTrait::<PossibleEntries>::new();
// //         let (entries, entries_len, last_updated_timestamp) = get_data_entries(data_type, sources);
// //         if (entries_len == 0) {
// //             return PragmaPricesResponse {
// //                 price: 0,
// //                 decimals: 0,
// //                 last_updated_timestamp: 0,
// //                 num_sources_aggregated: 0,
// //                 expiration_timestamp: Option::Some(0),
// //             };
// //         }
// //         let filtered_entries: ArrayEntry = filter_data_array(data_type, @entries);

//     // //TODO change timestmap
//     // impl CheckpointStorageAccess of StorageAccess<Checkpoint> {
//     //     fn read(address_domain: u32, base: StorageBaseAddress) -> SyscallResult<Checkpoint> {
//     //         let timestamp_base = storage_base_address_from_felt252(
//     //             storage_address_from_base_and_offset(base, 0_u8).into()
//     //         );
//     //         let timestamp: u64 = StorageAccess::<u128>::read(address_domain, timestamp_base)?
//     //             .try_into()
//     //             .unwrap();

// //     fn get_data_with_USD_hop(
// //         base_currency_id: felt252,
// //         quote_currency_id: felt252,
// //         aggregation_mode: AggregationMode,
// //         typeof: simpleDataType,
// //         expiration_timestamp: Option<u64>
// //     ) -> PragmaPricesResponse {
// //         let mut sources = ArrayTrait::<felt252>::new().span();
// //         let base_pair_id = oracle_pair_id_storage::read((base_currency_id, USD_CURRENCY_ID));
// //         let quote_pair_id = oracle_pair_id_storage::read((quote_currency_id, USD_CURRENCY_ID));
// //         let (base_data_type, quote_data_type, currency) = match typeof {
// //             simpleDataType::SpotEntry(()) => {
// //                 (
// //                     DataType::SpotEntry(base_pair_id),
// //                     DataType::SpotEntry(quote_pair_id),
// //                     oracle_currencies_storage::read(quote_currency_id)
// //                 )
// //             },
// //             simpleDataType::FutureEntry(()) => {
// //                 match expiration_timestamp {
// //                     Option::Some(expiration) => {
// //                         let base_dt = DataType::FutureEntry((base_pair_id, expiration));
// //                         let quote_dt = DataType::FutureEntry((quote_pair_id, expiration));
// //                         (base_dt, quote_dt, oracle_currencies_storage::read(quote_currency_id))
// //                     },
// //                     Option::None(_) => {
// //                         // Handle case where Future data type was provided without an expiration timestamp
// //                         assert(1 == 1, 'Requires expiration timestamp');
// //                         (
// //                             DataType::FutureEntry((base_pair_id, 0)),
// //                             DataType::FutureEntry((quote_pair_id, 0)),
// //                             oracle_currencies_storage::read(quote_currency_id)
// //                         )
// //                     }
// //                 }
// //             },
// //         };
// //         let basePPR: PragmaPricesResponse = get_data(base_data_type, aggregation_mode, sources);
// //         let quotePPR: PragmaPricesResponse = get_data(quote_data_type, aggregation_mode, sources);
// //         let decimals = min(get_decimals(base_data_type), get_decimals(quote_data_type));
// //         let rebased_value = convert_via_usd(basePPR.price, quotePPR.price, decimals);
// //         let last_updated_timestamp = max(
// //             quotePPR.last_updated_timestamp, basePPR.last_updated_timestamp
// //         );
// //         let num_sources_aggregated = max(
// //             quotePPR.num_sources_aggregated, basePPR.num_sources_aggregated
// //         );
// //         PragmaPricesResponse {
// //             price: rebased_value,
// //             decimals: decimals,
// //             last_updated_timestamp: last_updated_timestamp,
// //             num_sources_aggregated: num_sources_aggregated,
// //             expiration_timestamp: expiration_timestamp,
// //         }
// //     }

// //     fn get_data_entry(data_type: DataType, source: felt252) -> PossibleEntries {
// //         let _entry = match data_type {
// //             DataType::SpotEntry(pair_id) => {
// //                 oracle_data_entry_storage::read((pair_id, source, SPOT, 0))
// //             },
// //             DataType::FutureEntry((
// //                 pair_id, expiration_timestamp
// //             )) => {
// //                 oracle_data_entry_storage::read((pair_id, source, FUTURE, expiration_timestamp))
// //             },
// //         };
// //         let u256_timestamp = actual_get_element_at(_entry, 0, 31);
// //         let timestamp: u64 = u256_timestamp.try_into().unwrap().try_into().unwrap();
// //         let volume = actual_get_element_at(_entry, 32, 42);
// //         let price = actual_get_element_at(_entry, 75, 128);
// //         match data_type {
// //             DataType::SpotEntry(pair_id) => {
// //                 PossibleEntries::Spot(
// //                     SpotEntry {
// //                         base: BaseEntry {
// //                             timestamp: timestamp, source: source, publisher: 0
// //                         }, pair_id: pair_id, price: price, volume: volume
// //                     }
// //                 )
// //             },
// //             DataType::FutureEntry((
// //                 pair_id, expiration_timestamp
// //             )) => {
// //                 PossibleEntries::Future(
// //                     FutureEntry {
// //                         base: BaseEntry {
// //                             timestamp: timestamp, source: source, publisher: 0
// //                         },
// //                         pair_id: pair_id,
// //                         price: price,
// //                         volume: volume,
// //                         expiration_timestamp: expiration_timestamp
// //                     }
// //                 )
// //             },
// //         }
// //     }

// //     // fn get_data_entry(data_type: DataType, source: felt252) -> T {
// //     //     let _entry = match data_type {
// //     //         DataType::SpotEntry(pair_id) => {
// //     //             oracle_data_entry_storage::read((pair_id, source, SPOT, 0))
// //     //         },
// //     //         DataType::FutureEntry((
// //     //             pair_id, expiration_timestamp
// //     //         )) => {
// //     //             oracle_data_entry_storage::read((pair_id, source, FUTURE, expiration_timestamp))
// //     //         },
// //     //     };
// //     //     let timestamp = actual_get_element_at(_entry.timestamp__volume__price, 0, 31);
// //     //     let volume = actual_get_element_at(_entry.timestamp__volume__price, 32, 42);
// //     //     let price = actual_get_element_at(_entry.timestamp__volume__price, 75, 128);
// //     //     match data_type {
// //     //         DataType::SpotEntry(pair_id) => {
// //     //             return SpotEntry {
// //     //                 base: BaseEntry {
// //     //                     timestamp: timestamp, source: source, publisher: 0
// //     //                 }, pair_id: pair_id, price: price, volume: volume
// //     //             };
// //     //         },
// //     //         DataType::FutureEntry((
// //     //             pair_id, expiration_timestamp
// //     //         )) => {
// //     //             return FutureEntry {
// //     //                 base: BaseEntry {
// //     //                     timestamp: timestamp, source: source, publisher: 0
// //     //                 },
// //     //                 pair_id: pair_id,
// //     //                 price: price,
// //     //                 volume: volume,
// //     //                 expiration_timestamp: expiration_timestamp
// //     //             };
// //     //         },
// //     //     }
// //     // }

// //     fn get_admin_address() -> ContractAddress {
// //         return Admin::get_admin_address();
// //     }

// //     fn get_publisher_registry_address() -> ContractAddress {
// //         let publisher_registry_address = oracle_publisher_registry_address_storage::read();
// //         return publisher_registry_address;
// //     }

// //     fn get_latest_checkpoint_index(data_type: DataType, aggregation_mode: AggregationMode) -> u64 {
// //         let checkpoint_index = match data_type {
// //             DataType::SpotEntry(pair_id) => {
// //                 oracle_checkpoint_index::read((pair_id, SPOT, 0))
// //             },
// //             DataType::FutureEntry((
// //                 pair_id, expiration_timestamp
// //             )) => {
// //                 oracle_checkpoint_index::read((pair_id, FUTURE, expiration_timestamp))
// //             },
// //         };
// //         return checkpoint_index;
// //     }

// //     fn get_data_entries(
// //         data_type: DataType, sources: Span<felt252>
// //     ) -> (Array<PossibleEntries>, u32, u64) {
// //         let last_updated_timestamp = get_latest_entry_timestamp(data_type, sources);
// //         let current_timestamp: u64 = get_block_timestamp();
// //         let conservative_current_timestamp = min(last_updated_timestamp, current_timestamp);
// //         let (entries, entries_len) = get_all_entries(
// //             data_type, sources, conservative_current_timestamp
// //         );
// //         return (entries, entries_len, last_updated_timestamp);
// //     }

// //     fn get_sources_threshold() -> u32 {
// //         oracle_sources_threshold_storage::read()
// //     }
// //     fn get_latest_checkpoint(data_type: DataType, aggregation_mode: AggregationMode) -> Checkpoint {
// //         let cur_idx = get_latest_checkpoint_index(data_type, aggregation_mode);
// //         let latest_checkpoint = match data_type {
// //             DataType::SpotEntry(pair_id) => {
// //                 oracle_checkpoints::read((pair_id, SPOT, cur_idx, 0))
// //             },
// //             DataType::FutureEntry((
// //                 pair_id, expiration_timestamp
// //             )) => {
// //                 oracle_checkpoints::read((pair_id, FUTURE, cur_idx, expiration_timestamp))
// //             },
// //         };
// //         return latest_checkpoint;
// //     }

// //     //
// //     //Setters
// //     //

// //     fn publish_data(new_entry: PossibleEntries) {
// //         match new_entry {
// //             PossibleEntries::Spot(spot_entry) => {
// //                 validate_sender_for_source(spot_entry);
// //                 let entry: PossibleEntries = get_data_entry(
// //                     DataType::SpotEntry(spot_entry.pair_id), spot_entry.base.source
// //                 );
// //                 match entry {
// //                     PossibleEntries::Spot(spot) => {
// //                         validate_data_timestamp(new_entry, spot);
// //                         SubmittedSpotEntry(spot_entry);
// //                         let conv_timestamp: u256 = u256 {
// //                             low: spot_entry.base.timestamp.into(), high: 0
// //                         };
// //                         let element = actual_set_element_at(0, 0, 31, conv_timestamp);
// //                         let element = actual_set_element_at(element, 32, 42, spot_entry.volume);
// //                         let element = actual_set_element_at(element, 75, 128, spot_entry.price);
// //                         let spot_entry_storage = SpotEntryStorage {
// //                             timestamp__volume__price: element
// //                         };
// //                         oracle_data_entry_storage::write(
// //                             (spot_entry.pair_id, SPOT, spot_entry.base.source, 0), element
// //                         );
// //                     },
// //                     PossibleEntries::Future(_) => {
// //                         assert(1 == 1, 'Failed fetching spot entry');
// //                     },
// //                 }
// //             },
// //             PossibleEntries::Future(future_entry) => {
// //                 validate_sender_for_source(future_entry);
// //                 let entry: PossibleEntries = get_data_entry(
// //                     DataType::FutureEntry(
// //                         (future_entry.pair_id, future_entry.expiration_timestamp)
// //                     ),
// //                     future_entry.base.source
// //                 );
// //                 match entry {
// //                     PossibleEntries::Spot(_) => {
// //                         assert(1 == 1, 'Failed fetching future entry');
// //                     },
// //                     PossibleEntries::Future(future) => {
// //                         validate_data_timestamp::<FutureEntry>(new_entry, future);
// //                         SubmittedFutureEntry(future_entry);
// //                         let conv_timestamp: u256 = u256 {
// //                             low: future_entry.base.timestamp.into(), high: 0
// //                         };
// //                         let element = actual_set_element_at(0, 0, 31, conv_timestamp);
// //                         let element = actual_set_element_at(element, 32, 42, future_entry.volume);
// //                         let element = actual_set_element_at(element, 75, 128, future_entry.price);
// //                         let future_entry_storage = FutureEntryStorage {
// //                             timestamp__volume__price: element
// //                         };
// //                         oracle_data_entry_storage::write(
// //                             (
// //                                 future_entry.pair_id,
// //                                 FUTURE,
// //                                 future_entry.base.source,
// //                                 future_entry.expiration_timestamp
// //                             ),
// //                             element
// //                         );
// //                     },
// //                 }
// //             },
// //         }
// //         return ();
// //     }
// //     fn update_publisher_registry_address(new_publisher_registry_address: ContractAddress) {
// //         let old_publisher_registry_address = oracle_publisher_registry_address_storage::read();
// //         oracle_publisher_registry_address_storage::write(new_publisher_registry_address);
// //         UpdatedPublisherRegistryAddress(
// //             old_publisher_registry_address, new_publisher_registry_address
// //         );
// //         return ();
// //     }

// //     fn add_currency(currency: Currency) {
// //         let existing_currency = oracle_currencies_storage::read(currency.id);
// //         assert(existing_currency.id == 0, 'Currency already exists for key');
// //         SubmittedCurrency(currency);
// //         oracle_currencies_storage::write(currency.id, currency);
// //         return ();
// //     }

// //     fn update_currency(currency: Currency, typeof: felt252) {
// //         oracle_currencies_storage::write(currency.id, currency);
// //         UpdatedCurrency(currency);
// //         return ();
// //     }

// //     fn set_checkpoint(data_type: DataType, aggregation_mode: AggregationMode) {
// //         let mut sources = ArrayTrait::<felt252>::new().span();
// //         let priceResponse = get_data(data_type, aggregation_mode, sources);
// //         let sources_threshold = oracle_sources_threshold_storage::read();
// //         let cur_checkpoint = get_latest_checkpoint(data_type, aggregation_mode);
// //         let timestamp: u64 = get_block_timestamp();
// //         if (sources_threshold < priceResponse.num_sources_aggregated
// //             & (cur_checkpoint.timestamp + 1) < timestamp) {
// //             let new_checkpoint = Checkpoint {
// //                 timestamp: timestamp,
// //                 value: priceResponse.price,
// //                 aggregation_mode: aggregation_mode,
// //                 num_sources_aggregated: priceResponse.num_sources_aggregated
// //             };
// //             match data_type {
// //                 DataType::SpotEntry(pair_id) => {
// //                     let cur_idx = oracle_checkpoint_index::read((pair_id, SPOT, 0));
// //                     oracle_checkpoints::write((pair_id, SPOT, cur_idx, 0), new_checkpoint);
// //                     oracle_checkpoint_index::write((pair_id, SPOT, 0), cur_idx + 1);
// //                     CheckpointSpotEntry(pair_id);
// //                 },
// //                 DataType::FutureEntry((
// //                     pair_id, expiration_timestamp
// //                 )) => {
// //                     let cur_idx = oracle_checkpoint_index::read(
// //                         (pair_id, FUTURE, expiration_timestamp)
// //                     );
// //                     oracle_checkpoints::write(
// //                         (pair_id, FUTURE, cur_idx, expiration_timestamp), new_checkpoint
// //                     );
// //                     oracle_checkpoint_index::write(
// //                         (pair_id, FUTURE, expiration_timestamp), cur_idx + 1
// //                     );
// //                     CheckpointFutureEntry(pair_id, expiration_timestamp);
// //                 },
// //             }
// //         }
// //         return ();
// //     }

// //     fn set_checkpoints(data_types: Span<DataType>, aggregation_mode: AggregationMode) {
// //         let mut cur_idx: u32 = 0;
// //         loop {
// //             if (cur_idx == data_types.len()) {
// //                 break ();
// //             }
// //             let data_type: DataType = *data_types.get(cur_idx).unwrap().unbox();
// //             set_checkpoint(data_type, aggregation_mode);
// //             cur_idx += 1;
// //         }
// //     }

// //     fn get_decimals_for_currency(currency_id: felt252, typeof: felt252) -> u32 {
// //         let key_currency = oracle_currencies_storage::read(currency_id);
// //         if (key_currency.id == 0) {
// //             return 0;
// //         }
// //         key_currency.decimals
// //     }

// //     //
// //     //Guard
// //     //
// //     fn only_oracle_controller() {
// //         let caller_address = get_caller_address();
// //         let oracle_controller_address = oracle_controller_address_storage::read();
// //         if (oracle_controller_address.is_zero()) {
// //             return ();
// //         }
// //         assert(caller_address == oracle_controller_address, 'Needs to be oracle controller');
// //         return ();
// //     }

// //     //
// //     //Internal
// //     //
// //     fn build_sources_array(data_type: DataType, ref sources: Array<felt252>, idx: u64) {
// //         match data_type {
// //             DataType::SpotEntry(pair_id) => {
// //                 let new_source = oracle_sources_storage::read((pair_id, SPOT, idx, 0));
// //                 sources.append(new_source);
// //             },
// //             DataType::FutureEntry((
// //                 pair_id, expiration_timestamp
// //             )) => {
// //                 let new_source = oracle_sources_storage::read(
// //                     (pair_id, FUTURE, idx, expiration_timestamp)
// //                 );
// //                 sources.append(new_source);
// //             }
// //         }
// //     }

// //     fn get_latest_entry_timestamp(data_type: DataType, sources: Span<felt252>) -> u64 {
// //         let mut cur_idx = 0;
// //         let mut latest_timestamp = 0;
// //         loop {
// //             if (cur_idx >= sources.len()) {
// //                 break ();
// //             }
// //             let source: felt252 = *sources.get(cur_idx).unwrap().unbox();
// //             let entry: PossibleEntries = get_data_entry(data_type, source);
// //             match entry {
// //                 PossibleEntries::Spot(spot_entry) => {
// //                     if spot_entry.base.timestamp > latest_timestamp {
// //                         latest_timestamp = spot_entry.base.timestamp;
// //                     }
// //                 },
// //                 PossibleEntries::Future(future_entry) => {
// //                     if future_entry.base.timestamp > latest_timestamp {
// //                         latest_timestamp = future_entry.base.timestamp;
// //                     }
// //                 }
// //             }
// //             cur_idx += 1;
// //         };
// //         return latest_timestamp;
// //     }

// //     fn build_entries_array(
// //         data_type: DataType,
// //         sources: Span<felt252>,
// //         ref entries: Array<PossibleEntries>,
// //         latest_timestamp: u64
// //     ) {
// //         let mut cur_idx = 0;
// //         loop {
// //             if (cur_idx >= sources.len()) {
// //                 break ();
// //             }
// //             let source: felt252 = *sources.get(cur_idx).unwrap().unbox();
// //             let g_entry: PossibleEntries = get_data_entry(data_type, source);
// //             match g_entry {
// //                 PossibleEntries::Spot(spot_entry) => {
// //                     let is_entry_not_initialized: bool = spot_entry.get_base_timestamp() == 0;
// //                     let condition: bool = is_entry_not_initialized
// //                         & (spot_entry
// //                             .get_base_timestamp() < (latest_timestamp - BACKWARD_TIMESTAMP_BUFFER));
// //                     if !condition {
// //                         entries.append(PossibleEntries::Spot(spot_entry));
// //                     }
// //                 },
// //                 PossibleEntries::Future(future_entry) => {
// //                     let is_entry_not_initialized: bool = future_entry.get_base_timestamp() == 0;
// //                     let condition: bool = is_entry_not_initialized
// //                         & (future_entry
// //                             .get_base_timestamp() < (latest_timestamp - BACKWARD_TIMESTAMP_BUFFER));
// //                     if !condition {
// //                         entries.append(PossibleEntries::Future(future_entry));
// //                     }
// //                 }
// //             };

// //             cur_idx += 1;
// //         };
// //         return ();
// //     }

// //     fn get_checkpoint_by_index(data_type: DataType, checkpoint_index: u64) -> Checkpoint {
// //         let checkpoint = match data_type {
// //             DataType::SpotEntry(pair_id) => {
// //                 oracle_checkpoints::read((pair_id, SPOT, checkpoint_index, 0))
// //             },
// //             DataType::FutureEntry((
// //                 pair_id, expiration_timestamp
// //             )) => {
// //                 oracle_checkpoints::read((pair_id, FUTURE, checkpoint_index, expiration_timestamp))
// //             },
// //         };
// //         return checkpoint;
// //     }

// //     fn validate_sender_for_source<T, impl THasBaseEntry: hasBaseEntry<T>, impl TDrop: Drop<T>>(
// //         _entry: T
// //     ) {
// //         let publisher_registry_address = get_publisher_registry_address();
// //         let publisher_registry_dispatcher = IPublisherRegistryABIDispatcher {
// //             contract_address: publisher_registry_address
// //         };
// //         let publisher_address = publisher_registry_dispatcher
// //             .get_publisher_address(_entry.get_base_entry().publisher);

// //         let _can_publish_source = publisher_registry_dispatcher
// //             .can_publish_source(_entry.get_base_entry().publisher, _entry.get_base_entry().source);
// //         //CHECK IF THIS VERIFICATION WORKS 
// //         let caller_address = get_caller_address();
// //         assert(publisher_address.is_zero(), 'Publisher is not registered');
// //         assert(!caller_address.is_zero(), 'Caller must not be zero address');
// //         assert(caller_address == publisher_address, 'Transaction not from publisher');
// //         assert(_can_publish_source == true, 'Not allowed for source');
// //         return ();
// //     }

// //     fn get_all_sources(data_type: DataType) -> Array<felt252> {
// //         let mut sources = ArrayTrait::<felt252>::new();
// //         match data_type {
// //             DataType::SpotEntry(pair_id) => {
// //                 let source_len = oracle_sources_len_storage::read((pair_id, SPOT, 0));
// //                 build_sources_array(data_type, ref sources, source_len);
// //                 return sources;
// //             },
// //             DataType::FutureEntry((
// //                 pair_id, expiration_timestamp
// //             )) => {
// //                 let source_len = oracle_sources_len_storage::read(
// //                     (pair_id, FUTURE, expiration_timestamp)
// //                 );
// //                 build_sources_array(data_type, ref sources, source_len);
// //                 return sources;
// //             },
// //         }
// //     }

// //     fn get_all_entries(
// //         data_type: DataType, sources: Span<felt252>, max_timestamp: u64
// //     ) -> (Array<PossibleEntries>, u32) {
// //         let mut entries = ArrayTrait::<PossibleEntries>::new();
// //         if (sources.len() == 0) {
// //             let all_sources = get_all_sources(data_type).span();
// //             build_entries_array(data_type, all_sources, ref entries, max_timestamp);
// //             (entries, entries.len())
// //         } else {
// //             build_entries_array(data_type, sources, ref entries, max_timestamp);
// //             (entries, entries.len())
// //         }
// //     }

// //     fn filter_data_array(data_type: DataType, data: @Array<PossibleEntries>) -> ArrayEntry {
// //         match data_type {
// //             DataType::SpotEntry(pair_id) => {
// //                 let mut cur_idx = 0;
// //                 let mut spot_entries = ArrayTrait::<SpotEntry>::new();
// //                 loop {
// //                     if (cur_idx >= data.len()) {
// //                         break ();
// //                     }
// //                     let entry = *data.at(cur_idx);
// //                     match entry {
// //                         PossibleEntries::Spot(spot_entry) => {
// //                             spot_entries.append(spot_entry);
// //                         },
// //                         PossibleEntries::Future(_) => {
// //                             assert(false, 'Invalid entry type');
// //                         }
// //                     }
// //                     cur_idx = cur_idx + 1;
// //                 };
// //                 ArrayEntry::SpotEntry(spot_entries)
// //             },
// //             DataType::FutureEntry((
// //                 pair_id, expiration_timestamp
// //             )) => {
// //                 let mut cur_idx = 0;
// //                 let mut future_entries = ArrayTrait::<FutureEntry>::new();
// //                 loop {
// //                     if (cur_idx >= data.len()) {
// //                         break ();
// //                     }
// //                     let entry = *data.at(cur_idx);
// //                     match entry {
// //                         PossibleEntries::Spot(_) => {
// //                             assert(false, 'Invalid entry type');
// //                         },
// //                         PossibleEntries::Future(future_entry) => {
// //                             future_entries.append(future_entry);
// //                         }
// //                     }
// //                     cur_idx = cur_idx + 1;
// //                 };
// //                 ArrayEntry::FutureEntry(future_entries)
// //             }
// //         }
// //     }
// //     fn validate_data_timestamp<T, impl THasBaseEntry: hasBaseEntry<T>, impl TDrop: Drop<T>>(
// //         new_entry: PossibleEntries, last_entry: T
// //     ) {
// //         match new_entry {
// //             PossibleEntries::Spot(spot_entry) => {
// //                 assert(
// //                     spot_entry.get_base_timestamp() > last_entry.get_base_timestamp(),
// //                     'Existing entry is more recent'
// //                 );
// //                 if (last_entry.get_base_timestamp() == 0) {
// //                     let sources_len = oracle_sources_len_storage::read(
// //                         (spot_entry.pair_id, SPOT, 0)
// //                     );
// //                     oracle_sources_storage::write(
// //                         (spot_entry.pair_id, SPOT, sources_len, 0),
// //                         spot_entry.get_base_entry().source
// //                     );
// //                     oracle_sources_len_storage::write(
// //                         (spot_entry.pair_id, SPOT, 0), sources_len + 1
// //                     );
// //                 }
// //             },
// //             PossibleEntries::Future(future_entry) => {
// //                 assert(
// //                     future_entry.get_base_timestamp() > last_entry.get_base_timestamp(),
// //                     'Existing entry is more recent'
// //                 );
// //                 if (last_entry.get_base_timestamp() == 0) {
// //                     let sources_len = oracle_sources_len_storage::read(
// //                         (future_entry.pair_id, FUTURE, future_entry.expiration_timestamp)
// //                     );
// //                     oracle_sources_storage::write(
// //                         (
// //                             future_entry.pair_id,
// //                             FUTURE,
// //                             sources_len,
// //                             future_entry.expiration_timestamp
// //                         ),
// //                         future_entry.get_base_entry().source
// //                     );
// //                     oracle_sources_len_storage::write(
// //                         (future_entry.pair_id, FUTURE, future_entry.expiration_timestamp),
// //                         sources_len + 1
// //                     );
// //                 }
// //             },
// //         // PossibleEntries::OptionEntry(option_entry) => {}
// //         }
// //         return ();
// //     }

// //     fn add_pair(pair: Pair) {
// //         let check_pair = oracle_pairs_storage::read(pair.id);
// //         assert(check_pair.id == 0, 'Pair with this key registered');
// //         SubmittedPair(pair);
// //         oracle_pairs_storage::write(pair.id, pair);
// //         oracle_pair_id_storage::write((pair.quote_currency_id, pair.base_currency_id), pair.id);
// //         return ();
// //     }

// //     fn _set_keys_currencies(key_currencies: Span<Currency>, idx: usize) {
// //         let mut idx: u32 = 0;
// //         loop {
// //             if (idx == key_currencies.len()) {
// //                 break ();
// //             }

// //             let key_currency = *key_currencies.get(idx).unwrap().unbox();
// //             oracle_currencies_storage::write(key_currency.id, key_currency);
// //             idx = idx + 1;
// //         };
// //         return ();
// //     }

// //     fn set_sources_threshold(threshold: u32) {
// //         oracle_sources_threshold_storage::write(threshold);
// //         return ();
// //     }

// //     fn find_startpoint(
// //         data_type: DataType, aggregation_mode: AggregationMode, timestamp: u64
// //     ) -> u64 {
// //         let last_checkpoint_index = get_latest_checkpoint_index(data_type, aggregation_mode);
// //         let latest_checkpoint_index = get_latest_checkpoint_index(data_type, aggregation_mode);
// //         let cp = get_checkpoint_by_index(data_type, latest_checkpoint_index - 1);
// //         let first_cp = get_checkpoint_by_index(data_type, 0);
// //         if (cp.timestamp < timestamp) {
// //             return latest_checkpoint_index - 1;
// //         }

// //         if (timestamp < first_cp.timestamp) {
// //             return 0;
// //         }
// //         let startpoint = _binary_search(data_type, 0, latest_checkpoint_index, timestamp);
// //         return startpoint;
// //     }

// //     fn _binary_search(data_type: DataType, low: u64, high: u64, target: u64) -> u64 {
// //         let midpoint = (low + high) / 2;

// //         if (high == low) {
// //             return midpoint;
// //         }

// //         if ((high + 1) <= low) {
// //             return low - 1;
// //         }

// //         let cp = get_checkpoint_by_index(data_type, midpoint);
// //         let timestamp = cp.timestamp;

// //         if (timestamp == target) {
// //             return midpoint;
// //         }

// //         if (target <= timestamp) {
// //             return _binary_search(data_type, low, midpoint - 1, target);
// //         } else {
// //             return _binary_search(data_type, midpoint + 1, high, target);
// //         }
// //     }

// //     fn _set_keys_pairs(key_pairs: Span<Pair>) {
// //         let mut idx: u32 = 0;
// //         loop {
// //             if (idx >= key_pairs.len()) {
// //                 break ();
// //             }
// //             let key_pair = *key_pairs.get(idx).unwrap().unbox();
// //             oracle_pairs_storage::write(key_pair.id, key_pair);
// //             oracle_pair_id_storage::write(
// //                 (key_pair.quote_currency_id, key_pair.base_currency_id), key_pair.id
// //             );
// //             idx = idx + 1;
// //         };
// //         return ();
// //     }
// // }

