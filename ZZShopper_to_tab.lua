-- Read the SavedVariables file that ZZShopper creates and convert
-- that to a spreadsheet-compabitle tab-separated-value.

IN_FILE_PATH  = "data/ZZShopper.lua"
OUT_FILE_PATH = "data/ZZShopper.txt"
dofile(IN_FILE_PATH)
OUT_FILE = assert(io.open(OUT_FILE_PATH, "w"))

-- Scan 1: assign item index to each item
DATA = ZZShopperVars["Default"]["@ziggr"]["Zhaksyr the Mighty"]
GUILD_DATA  = DATA["guild"]
LISTINGS    = DATA["listings"]
START_TS_SEC = DATA["start_ts_sec"]

GUILD         = {}
ITEM_TO_INDEX = {}  -- name to index
ITEM_NAME     = {}  -- index to name

                    -- flatten and sort list of names
for item_name, guild_list in pairs(LISTINGS) do
    if not ITEM_TO_INDEX[item_name] then
        table.insert(ITEM_NAME, item_name)
        ITEM_TO_INDEX[item_name] = 0
    end
end
table.sort(ITEM_NAME)
                    -- replace placeholder "0" with real indices
for index, item_name in ipairs(ITEM_NAME) do
    ITEM_TO_INDEX[item_name] = index
end

-- Scan 2: pull guild info into indexed table
GUILD_MAX_INDEX = 0
for guild_name, guild_data in pairs(GUILD_DATA) do
    GUILD[guild_data.index] = guild_data
    GUILD_MAX_INDEX = math.max(GUILD_MAX_INDEX, guild_data.index)
end

-- Output
--
-- Three tables at once:
--
-- Listings:  item index, guild index, item_ct, price
-- Items:     item name, item index (ordered by item name)
-- Guilds:    guild index, guild name, guild zone
-- Convert "1456709816" to "2016-02-28T17:36:56" ISO 8601 formatted time
-- Assume "local machine time" and ignore any incorrect offsets due to
-- Daylight Saving Time transitions. Ugh.


function iso_date(secs_since_1970)
    local t              = os.date("*t", secs_since_1970)
    return string.format("%04d-%02d-%02dT%02d:%02d:%02d"
                        , t.year
                        , t.month
                        , t.day
                        , t.hour
                        , t.min
                        , t.sec
                        )
end

function tostr(x)
    if x then
        return tostring(x)
    else
        return ""
    end
end

-- From http://lua-users.org/wiki/SplitJoin
function split(str,sep)
    local ret={}
    local n=1
    for w in str:gmatch("([^"..sep.."]*)") do
        ret[n] = ret[n] or w -- only set once (so the blank after a string is ignored)
        if w=="" then
            n = n + 1
        end -- step forwards on a blank but not a string
    end
    return ret
end


function ToListings(listings_string)
    local listings = {}
    local lstrings = split(listings_string, "\t")
    for _, l in ipairs(lstrings) do
        local w = split(l, "@")
        local listing = { item_ct = tonumber(w[1])
                        , price   = tonumber(w[2])
                        }
        table.insert(listings, listing)
    end
    return listings
end


function RowString(args)
    local t = { tostr( args.listing_item_index  )
              , tostr( args.listing_guild_index )
              , tostr( args.listing_item_ct     )
              , tostr( args.listing_price       )
              , ""
              , tostr( args.item_name           )
              , tostr( args.item_index          )
              , ""
              , tostr( args.guild_index         )
              , tostr( args.guild_name          )
              , tostr( args.guild_zone          )
              }
    return table.concat(t, "\t")
end

function HeaderRowString()
    local args = { listing_item_index  = "item_index"
                 , listing_guild_index = "guild_index"
                 , listing_item_ct     = "item_ct"
                 , listing_price       = "price"
                 , item_name           = "item_name"
                 , item_index          = "item_index"
                 , guild_index         = "guild_index"
                 , guild_name          = "guild_name"
                 , guild_zone          = "guild_zone"
              }
    local row_string = RowString(args)
    local time_string = iso_date(START_TS_SEC)
    return "# "..row_string.."\t"..time_string
end

function OutputRow(
          row_index
        , listing_item_index
        , listing_guild_index
        , listing_item_ct
        , listing_price
        )
    local args = { listing_item_index  = listing_item_index
                 , listing_guild_index = listing_guild_index
                 , listing_item_ct     = listing_item_ct
                 , listing_price       = listing_price
                 }
                        -- Add any item and guild rows that also
                        -- go on this row.
    local item_name = ITEM_NAME[row_index]
    if item_name then
        args.item_name  = item_name
        args.item_index = row_index
    end
    local guild = GUILD[row_index]
    if guild then
        args.guild_index = row_index
        args.guild_name  = guild.name
        args.guild_zone  = guild.city
    end

    local row_string = RowString(args)

    OUT_FILE:write(row_string.."\n")
end

function OutputRows()
    local row_index = 0
    for item_name, guild_list in pairs(LISTINGS) do
        local item_index = ITEM_TO_INDEX[item_name]
        for guild_index, listings_string in pairs(guild_list) do
            local guild_index = guild_index
            local listings = ToListings(listings_string)
            for _, listing in ipairs(listings) do
                row_index = row_index + 1
                OutputRow( row_index
                         , item_index
                         , guild_index
                         , listing.item_ct
                         , listing.price
                         )
            end
        end
    end
end


OUT_FILE:write(HeaderRowString().."\n")
OutputRows()
OUT_FILE:close()
