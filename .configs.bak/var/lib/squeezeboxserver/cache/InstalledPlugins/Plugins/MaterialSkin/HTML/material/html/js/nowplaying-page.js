/**
 * LMS-Material
 *
 * Copyright (c) 2018 Craig-2019 Drummond <craig.p.drummond@gmail.com>
 * MIT license.
 */

const BIO_TAB = 0;
const REVIEW_TAB = 1;
const LYRICS_TAB = 2;

var lmsNowPlaying = Vue.component("lms-now-playing", {
    template: `
<div v-if="desktop && !largeView" class="np-bar noselect" id="np-bar">

 <v-layout row class="np-controls-desktop" v-if="stopButton">
  <v-flex xs3>
   <v-btn flat icon @click="doAction(['button', 'jump_rew'])"><v-icon large>skip_previous</v-icon></v-btn>
  </v-flex>
  <v-flex xs3>
   <v-btn flat icon large v-if="playerStatus.isplaying" @click="doAction(['pause'])" class="np-playpause"><v-icon large>pause</v-icon></v-btn>
   <v-btn flat icon large v-else @click="doAction(['play'])" class="np-playpause"><v-icon large>play_arrow</v-icon></v-btn>
  </v-flex>
  <v-flex xs3>
   <v-btn flat icon large @click="doAction(['stop'])" class="np-playpause"><v-icon large>stop</v-icon></v-btn>
  </v-flex>
  <v-flex xs3>
   <v-btn flat icon @click="doAction(['playlist', 'index', '+1'])"><v-icon large>skip_next</v-icon></v-btn>
  </v-flex>
 </v-layout>
 <v-layout row class="np-controls-desktop" v-else>
  <v-flex xs4>
   <v-btn flat icon @click="doAction(['button', 'jump_rew'])"><v-icon large>skip_previous</v-icon></v-btn>
  </v-flex>
  <v-flex xs4>
   <v-btn flat icon large v-if="playerStatus.isplaying" @click="doAction(['pause'])" class="np-playpause"><v-icon x-large>pause_circle_outline</v-icon></v-btn>
   <v-btn flat icon large v-else @click="doAction(['play'])" class="np-playpause"><v-icon x-large>play_circle_outline</v-icon></v-btn>
  </v-flex>
  <v-flex xs4>
   <v-btn flat icon @click="doAction(['playlist', 'index', '+1'])"><v-icon large>skip_next</v-icon></v-btn>
  </v-flex>
 </v-layout>
 <img :src="coverUrl" class="np-image-desktop"></img>
 <div>
  <v-layout row wrap>
   <v-flex xs12><p class="np-text-desktop ellipsis" v-if="playerStatus.current.title">{{playerStatus.current.title}}</p></v-flex>
   <v-flex xs12>
    <p class="np-text-sub-desktop subtext ellipsis" v-if="playerStatus.current.artist && playerStatus.current.album">{{playerStatus.current.artist}} - {{playerStatus.current.album}}</p>
    <p class="np-text-sub-desktop subtext ellipsis" v-else-if="playerStatus.current.artist">{{playerStatus.current.artist}}</p>
   </v-flex>
   <v-flex xs12>
    <p class="np-text-desktop subtext ellipsis" v-else-if="playerStatus.current.album">{{playerStatus.current.album}}</p>
   </v-flex>
   <v-flex xs12>
    <progress id="pos-slider" v-if="playerStatus.current.duration>0" class="np-slider np-slider-desktop" :value="playerStatus.current.pospc" v-on:click="sliderChanged($event)"></progress>
   </v-flex>
  </v-layout>
  <p class="np-text-desktop np-tech-desktop ellipsis" v-if="techInfo" :title="playerStatus.current.technicalInfo">{{playerStatus.current.technicalInfo}}</p>
  <p class="np-text-desktop np-time-desktop cursor" @click="toggleTime()">{{formattedTime}}</p>
 </div>
 <div v-if="info.show" class="np-info np-info-desktop bgnd-cover np-info-cover" id="np-info">
  <v-tabs centered v-model="info.tab" v-if="info.showTabs" style="np-info-tab-cover">
   <template v-for="(tab, index) in info.tabs">
    <v-tab :key="index">{{tab.title}}</v-tab>
    <v-tab-item :key="index" transition="" reverse-transition=""> <!-- background image causes glitches with transitions -->
     <v-card flat class="np-info-card-cover">
      <v-card-text class="np-info-text-desktop" v-bind:class="{'np-info-lyrics': LYRICS_TAB==index}" v-html="tab.text"></v-card-text>
     </v-card>
    </v-tab-item>
   </template>
  </v-tabs>
  <div v-else>
   <v-layout row>
    <template v-for="(tab, index) in info.tabs">
     <v-flex xs4>
      <v-card flat class="np-info-card-cover">
       <v-card-title><p>{{tab.title}}</p></v-card-title>
       <v-card-text class="np-info-text-full-desktop" v-bind:class="{'np-info-lyrics': LYRICS_TAB==index}" v-html="tab.text"></v-card-text>
      </v-card>
     </v-flex>
    </template>
   </v-layout>
  </div>
  <v-card class="np-info-card-cover">
   <v-card-actions>
    <v-spacer></v-spacer>
    <v-btn flat icon v-if="info.showTabs" @click="info.showTabs=false" :title="trans.collapse"><v-icon style="margin-right:-18px">chevron_left</v-icon><v-icon style="margin-left:-18px">chevron_right</v-icon></v-btn>
    <v-btn flat icon v-else @click="info.showTabs=true" :title="trans.expand"><v-icon style="margin-right:-18px">chevron_right</v-icon><v-icon style="margin-left:-18px">chevron_left</v-icon></v-btn>
    <div style="width:32px"></div>
    <v-btn flat icon v-if="info.sync" @click="info.sync = false" :title="trans.sync"><v-icon>link</v-icon></v-btn>
    <v-btn flat icon v-else @click="info.sync = true" :title="trans.unsync"><v-icon>link_off</v-icon></v-btn>
    <div style="width:32px"></div>
    <v-btn flat icon @click="trackInfo()" :title="trans.more"><v-icon>more_horiz</v-icon></v-btn>
    <div style="width:32px"></div>
    <v-btn flat icon @click="info.show = false" :title="trans.close"><v-icon>close</v-icon></v-btn>
    <v-spacer></v-spacer>
   </v-card-actions>
  </v-card>
 </div>
</div>
<div class="np-page bgnd-cover" v-else id="np-page">
 <div v-if="info.show" class="np-info bgnd-cover" id="np-info">
  <v-tabs centered v-model="info.tab" class="np-info-tab-cover">
   <template v-for="(tab, index) in info.tabs">
    <v-tab :key="index">{{tab.title}}</v-tab>
    <v-tab-item :key="index" transition="" reverse-transition=""> <!-- background image causes glitches with transitions -->
     <v-card flat class="np-info-card-cover">
      <v-card-text class="np-info-text" v-bind:class="{'np-info-lyrics': LYRICS_TAB==index}" v-html="tab.text"></v-card-text>
     </v-card>
    </v-tab-item>
   </template>
  </v-tabs>
  <v-card class="np-info-card-cover">
   <v-card-actions>
    <v-spacer></v-spacer>
    <v-btn flat icon v-if="info.sync" @click="info.sync = false" :title="trans.sync"><v-icon>link</v-icon></v-btn>
    <v-btn flat icon v-else @click="info.sync = true" :title="trans.unsync"><v-icon>link_off</v-icon></v-btn>
    <div style="width:32px"></div>
    <v-btn flat icon @click="trackInfo()" :title="trans.more"><v-icon>more_horiz</v-icon></v-btn>
    <div style="width:32px"></div>
    <v-btn flat icon @click="info.show = false" :title="trans.close"><v-icon>close</v-icon></v-btn>
    <v-spacer></v-spacer>
   </v-card-actions>
  </v-card>
 </div>
 <div v-else>
  <div v-if="landscape">
   <img v-if="!info.show" :src="coverUrl" class="np-image-landscape" v-bind:class="{'np-image-landscape-wide': wide}"></img>
   <div class="np-details-landscape">
    <div class="np-text-landscape np-title" v-if="playerStatus.current.title">{{playerStatus.current.title}}</div>
    <div class="np-text-landscape" v-else>&nbsp;</div>
    <div class="np-text-landscape subtext" v-if="playerStatus.current.artist">{{playerStatus.current.artist}}</div>
    <div class="np-text-landscape" v-else>&nbsp;</div>
    <div class="np-text-landscape subtext" v-if="playerStatus.current.album">{{playerStatus.current.album}}</div>
    <div class="np-text-landscape" v-else>&nbsp;</div>
    <div v-if="wide">

     <v-layout text-xs-center row wrap class="np-controls-wide">
      <v-flex xs3 class="np-pos" v-if="!info.show">{{playerStatus.current.time | displayTime}}</v-flex>
      <v-flex xs6 class="np-tech ellipsis" v-if="techInfo">{{playerStatus.current.technicalInfo}}</v-flex>
      <v-flex xs6 v-else></v-flex>
      <v-flex xs3 class="np-duration cursor" v-if="!info.show && (showTotal || !playerStatus.current.time)" @click="toggleTime()">{{playerStatus.current.duration | displayTime}}</v-flex>
      <v-flex xs3 class="np-duration cursor" v-else-if="!info.show && !showTotal" @click="toggleTime()">-{{playerStatus.current.duration-playerStatus.current.time | displayTime}}</v-flex>
      <v-flex xs12 v-if="!info.show && playerStatus.current.duration>0">
       <progress id="pos-slider" class="np-slider-mobile" :value="playerStatus.current.pospc" v-on:click="sliderChanged($event)"></progress>
      </v-flex>
      <v-flex xs4>
       <v-layout text-xs-center>
        <v-flex xs6>
         <v-btn :title="trans.repeatOne" flat icon v-if="playerStatus.playlist.repeat===1" @click="doAction(['playlist', 'repeat', 0])"><v-icon>repeat_one</v-icon></v-btn>
         <v-btn :title="trans.repeatAll" flat icon v-else-if="playerStatus.playlist.repeat===2" @click="doAction(['playlist', 'repeat', 1])"><v-icon>repeat</v-icon></v-btn>
         <v-btn :title="trans.repeatOff" flat icon v-else @click="doAction(['playlist', 'repeat', 2])" class="dimmed"><v-icon>repeat</v-icon></v-btn>
        </v-flex>
        <v-flex xs6><v-btn flat icon @click="doAction(['button', 'jump_rew'])"><v-icon large>skip_previous</v-icon></v-btn></v-flex>
       </v-layout>
      </v-flex>
      <v-flex xs4>
       <v-layout v-if="stopButton" text-xs-center>
        <v-flex xs6>
         <v-btn flat icon v-if="playerStatus.isplaying" @click="doAction(['pause'])"><v-icon large>pause</v-icon></v-btn>
         <v-btn flat icon v-else @click="doAction(['play'])"><v-icon large>play_arrow</v-icon></v-btn>
        </v-flex>
        <v-flex xs6>
         <v-btn flat icon @click="doAction(['stop'])"><v-icon large>stop</v-icon></v-btn>
        </v-flex>
       </v-layout>
       <v-btn flat icon large v-else-if="playerStatus.isplaying" @click="doAction(['pause'])" class="np-playpause"><v-icon x-large>pause_circle_outline</v-icon></v-btn>
       <v-btn flat icon large v-else @click="doAction(['play'])" class="np-playpause"><v-icon x-large>play_circle_outline</v-icon></v-btn>
      </v-flex>
      <v-flex xs4>
       <v-layout text-xs-center>
        <v-flex xs6><v-btn flat icon @click="doAction(['playlist', 'index', '+1'])"><v-icon large>skip_next</v-icon></v-btn></v-flex>
        <v-flex xs6>
         <v-btn :title="trans.shuffleAlbums" flat icon v-if="playerStatus.playlist.shuffle===2" @click="doAction(['playlist', 'shuffle', 0])"><v-icon class="shuffle-albums">shuffle</v-icon></v-btn>
         <v-btn :title="trans.shuffleAll" flat icon v-else-if="playerStatus.playlist.shuffle===1" @click="doAction(['playlist', 'shuffle', 2])"><v-icon>shuffle</v-icon></v-btn>
         <v-btn :title="trans.shuffleOff" flat icon v-else @click="doAction(['playlist', 'shuffle', 1])" class="dimmed"><v-icon>shuffle</v-icon></v-btn>
        </v-flex>
       </v-layout>
      </v-flex>
     </v-layout>

    </div>
   </div>
  </div>
  <div v-else>
   <p class="np-text np-title ellipsis" v-if="playerStatus.current.title">{{playerStatus.current.title}}</p>
   <p class="np-text" v-else>&nbsp;</p>
   <p class="np-text subtext ellipsis" v-if="playerStatus.current.artist">{{playerStatus.current.artist}}</p>
   <p class="np-text" v-else>&nbsp;</p>
   <p class="np-text subtext ellipsis" v-if="playerStatus.current.album">{{playerStatus.current.album}}</p>
   <p class="np-text" v-else>&nbsp;</p>
   <img v-if="!info.show" :src="coverUrl" class="np-image"></img>
  </div>

  <v-layout text-xs-center row wrap class="np-controls" v-if="!wide">
   <v-flex xs3 class="np-pos" v-if="!info.show">{{playerStatus.current.time | displayTime}}</v-flex>
   <v-flex xs6 class="np-tech ellipsis" v-if="techInfo">{{playerStatus.current.technicalInfo}}</v-flex>
   <v-flex xs6 v-else></v-flex>
   <v-flex xs3 class="np-duration cursor" v-if="!info.show && (showTotal || !playerStatus.current.time)" @click="toggleTime()">{{playerStatus.current.duration | displayTime}}</v-flex>
   <v-flex xs3 class="np-duration cursor" v-else-if="!info.show && !showTotal" @click="toggleTime()">-{{playerStatus.current.duration-playerStatus.current.time | displayTime}}</v-flex>
   <v-flex xs12 v-if="!info.show && playerStatus.current.duration>0">
    <progress id="pos-slider" class="np-slider-mobile" :value="playerStatus.current.pospc" v-on:click="sliderChanged($event)"></progress>
   </v-flex>
   <v-flex xs4>
    <v-layout text-xs-center>
     <v-flex xs6>
      <v-btn :title="trans.repeatOne" flat icon v-if="playerStatus.playlist.repeat===1" @click="doAction(['playlist', 'repeat', 0])"><v-icon>repeat_one</v-icon></v-btn>
      <v-btn :title="trans.repeatAll" flat icon v-else-if="playerStatus.playlist.repeat===2" @click="doAction(['playlist', 'repeat', 1])"><v-icon>repeat</v-icon></v-btn>
      <v-btn :title="trans.repeatOff" flat icon v-else @click="doAction(['playlist', 'repeat', 2])" class="dimmed"><v-icon>repeat</v-icon></v-btn>
     </v-flex>
     <v-flex xs6><v-btn flat icon @click="doAction(['button', 'jump_rew'])"><v-icon large>skip_previous</v-icon></v-btn></v-flex>
    </v-layout>
   </v-flex>
   <v-flex xs4>
    <v-layout v-if="stopButton" text-xs-center>
     <v-flex xs6>
      <v-btn flat icon v-if="playerStatus.isplaying" @click="doAction(['pause'])"><v-icon large>pause</v-icon></v-btn>
      <v-btn flat icon v-else @click="doAction(['play'])"><v-icon large>play_arrow</v-icon></v-btn>
     </v-flex>
     <v-flex xs6>
      <v-btn flat icon @click="doAction(['stop'])"><v-icon large>stop</v-icon></v-btn>
     </v-flex>
    </v-layout>
    <v-btn flat icon large v-else-if="playerStatus.isplaying" @click="doAction(['pause'])" class="np-playpause"><v-icon x-large>pause_circle_outline</v-icon></v-btn>
    <v-btn flat icon large v-else @click="doAction(['play'])" class="np-playpause"><v-icon x-large>play_circle_outline</v-icon></v-btn>
   </v-flex>
   <v-flex xs4>
    <v-layout text-xs-center>
     <v-flex xs6><v-btn flat icon @click="doAction(['playlist', 'index', '+1'])"><v-icon large>skip_next</v-icon></v-btn></v-flex>
     <v-flex xs6>
      <v-btn :title="trans.shuffleAlbums" flat icon v-if="playerStatus.playlist.shuffle===2" @click="doAction(['playlist', 'shuffle', 0])"><v-icon class="shuffle-albums">shuffle</v-icon></v-btn>
      <v-btn :title="trans.shuffleAll" flat icon v-else-if="playerStatus.playlist.shuffle===1" @click="doAction(['playlist', 'shuffle', 2])"><v-icon>shuffle</v-icon></v-btn>
      <v-btn :title="trans.shuffleOff" flat icon v-else @click="doAction(['playlist', 'shuffle', 1])" class="dimmed"><v-icon>shuffle</v-icon></v-btn>
     </v-flex>
    </v-layout>
   </v-flex>
  </v-layout>
 </div>
</div>
`,
    props: [ 'desktop' ],
    data() {
        return { desktop:false,
                 coverUrl:undefined,
                 playerStatus: {
                    isplaying: 1,
                    current: { canseek:1, duration:0, time:0, title:undefined, artist:undefined, 
                               album:undefined, albumName:undefined, technicalInfo: "", pospc:0.0 },
                    playlist: { shuffle:0, repeat: 0 },
                 },
                 info: { show: false, tab:LYRICS_TAB, showTabs:false, sync: true,
                         tabs: [ { title:undefined, text:undefined }, { title:undefined, text:undefined }, { title:undefined, text:undefined } ] },
                 trans: { close: undefined, expand:undefined, collapse:undefined, sync:undefined, unsync:undefined, more:undefined,
                          repeatAll:undefined, repeatOne:undefined, repeatOff:undefined,
                          shuffleAll:undefined, shuffleAlbums:undefined, shuffleOff:undefined },
                 showTotal: true,
                 landscape: false,
                 wide: false,
                 largeView: false
                };
    },
    mounted() {
        if (this.desktop) {
            this.info.showTabs=getLocalStorageBool("showTabs", false);
            bus.$on('largeView', function(val) {
                if (val) {
                    this.info.show = false;
                }
                this.largeView = val;
            }.bind(this));
        }
        this.info.sync=getLocalStorageBool("syncInfo", true);
        bus.$on('playerStatus', function(playerStatus) {
            var playStateChanged = false;
            var trackChanged = false;
            // Have other items changed
            if (playerStatus.isplaying!=this.playerStatus.isplaying) {
                this.playerStatus.isplaying = playerStatus.isplaying;
                playStateChanged = true;
            }
            if (playerStatus.current.canseek!=this.playerStatus.current.canseek) {
                this.playerStatus.current.canseek = playerStatus.current.canseek;
            }
            if (playerStatus.current.duration!=this.playerStatus.current.duration) {
                this.playerStatus.current.duration = playerStatus.current.duration;
            }
            if (playerStatus.current.time!=this.playerStatus.current.time) {
                this.playerStatus.current.time = playerStatus.current.time;
            }
            this.setPosition();
            if (playerStatus.current.id!=this.playerStatus.current.id) {
                this.playerStatus.current.id = playerStatus.current.id;
            }
            if (playerStatus.current.title!=this.playerStatus.current.title) {
                this.playerStatus.current.title = playerStatus.current.title;
                trackChanged = true;
            }
            var artist = playerStatus.current.artist ? playerStatus.current.artist : playerStatus.current.trackartist;
            var artist_ids = playerStatus.current.artist_ids ? playerStatus.current.artist_ids : playerStatus.current.trackartist_ids;
            if (this.playerStatus.current.artist!=artist ||
                playerStatus.current.artist_id!=this.playerStatus.current.artist_id ||
                playerStatus.current.artist_ids!=artist_ids) {
                this.playerStatus.current.artist = artist;
                this.playerStatus.current.artist_id = playerStatus.current.artist_id;
                this.playerStatus.current.artist_ids = artist_ids;
                trackChanged = true;
            }
            if (playerStatus.current.albumartist!=this.playerStatus.current.albumartist ||
                playerStatus.current.albumartist_ids!=this.playerStatus.current.albumartist_ids ) {
                this.playerStatus.current.albumartist = playerStatus.current.albumartist;
                this.playerStatus.current.albumartist_ids = playerStatus.current.albumartist_ids;
                trackChanged = true;
            }
            if (playerStatus.current.album!=this.playerStatus.current.albumName ||
                playerStatus.current.album_id!=this.playerStatus.current.album_id) {
                this.playerStatus.current.albumName = playerStatus.current.album;
                this.playerStatus.current.album_id = playerStatus.current.album_id;
                if (playerStatus.current.year && playerStatus.current.year>0) {
                    this.playerStatus.current.album = this.playerStatus.current.albumName+" ("+ playerStatus.current.year+")";
                } else {
                    this.playerStatus.current.album = this.playerStatus.current.albumName;
                }
                trackChanged = true;
            }
            if (playerStatus.playlist.shuffle!=this.playerStatus.playlist.shuffle) {
                this.playerStatus.playlist.shuffle = playerStatus.playlist.shuffle;
            }
            if (playerStatus.playlist.repeat!=this.playerStatus.playlist.repeat) {
                this.playerStatus.playlist.repeat = playerStatus.playlist.repeat;
            }
            var technical = [];
            if (playerStatus.current.bitrate) {
                technical.push(playerStatus.current.bitrate);
            }
            if (playerStatus.current.type) {
                var bracket = playerStatus.current.type.indexOf(" (");
                technical.push(bracket>0 ? playerStatus.current.type.substring(0, bracket) : playerStatus.current.type);
            }
            technical=technical.join(", ");
            if (technical!=this.playerStatus.current.technicalInfo) {
                this.playerStatus.current.technicalInfo = technical;
            }

            if (trackChanged && this.info.sync) {
                this.setInfoTrack();
                this.showInfo();
            }

            if (playStateChanged) {
                if (this.playerStatus.isplaying) {
                    if (trackChanged) {
                        this.stopPositionInterval();
                    }
                    this.startPositionInterval();
                } else {
                    this.stopPositionInterval();
                }
            } else if (this.playerStatus.isplaying && trackChanged) {
                this.stopPositionInterval();
                this.startPositionInterval();
            }
        }.bind(this));
        // Refresh status now, in case we were mounted after initial status call
        bus.$emit('refreshStatus');

        this.page = document.getElementById("np-page");
        bus.$on('themeChanged', function() {
            this.setBgndCover();
        }.bind(this));

        this.landscape = isLandscape();
        this.wide = this.landscape && isWide();
        bus.$on('screenLayoutChanged', function() {
            this.landscape = isLandscape();
            this.wide = this.landscape && isWide();
        }.bind(this));

        bus.$on('currentCover', function(coverUrl) {
            this.coverUrl = coverUrl;
            this.setBgndCover();
        }.bind(this));
        bus.$emit('getCurrentCover');

        bus.$on('langChanged', function() {
            this.initItems();
        }.bind(this));
        this.initItems();

        bus.$on('info', function() {
            if (this.playerStatus && this.playerStatus.current && this.playerStatus.current.artist) {
                this.largeView = false;
                this.info.show=!this.info.show;
            }
        }.bind(this));

        this.showTotal = getLocalStorageBool('showTotal', true);
    },
    methods: {
        initItems() {
            this.trans = { close:i18n("Close"), expand:i18n("Show all information"), collapse:i18n("Show information in tabs"),
                           sync:i18n("Update information when song changes"), unsync:i18n("Don't update information when song changes"),
                           more:i18n("More"),
                           repeatAll:i18n("Repeat queue"), repeatOne:i18n("Repeat single track"), repeatOff:i18n("No repeat"),
                           shuffleAll:i18n("Shuffle tracks"), shuffleAlbums:i18n("Shuffle albums"), shuffleOff:i18n("No shuffle") };
            this.info.tabs[LYRICS_TAB].title=i18n("Lyrics");
            this.info.tabs[BIO_TAB].title=i18n("Artist Biography");
            this.info.tabs[REVIEW_TAB].title=i18n("Album Review");
        },
        doAction(command) {
            bus.$emit('playerCommand', command);
        },
        setPosition() {
            var pc = this.playerStatus.current && undefined!=this.playerStatus.current.time && undefined!=this.playerStatus.current.duration &&
                     this.playerStatus.current.duration>0 ? Math.floor(this.playerStatus.current.time*1000/this.playerStatus.current.duration)/1000 : 0.0;

            if (pc!=this.playerStatus.current.pospc) {
                this.playerStatus.current.pospc = pc;
            }
        },
        sliderChanged(e) {
            if (this.playerStatus.current.canseek && this.playerStatus.current.duration>3) {
                const rect = document.getElementById("pos-slider").getBoundingClientRect();
                const pos = e.clientX - rect.x;
                const width = rect.width;
                this.doAction(['time', Math.floor(this.playerStatus.current.duration * pos / rect.width)]);
            }
        },
        setInfoTrack() {
            this.infoTrack={ title: this.playerStatus.current.title,
                             artist: this.playerStatus.current.artist, artist_id: this.playerStatus.current.artist_id,
                             albumartist: this.playerStatus.current.albumartist, albumartist_ids: this.playerStatus.current.albumartist_ids,
                             artist_ids: this.playerStatus.current.artist_ids,
                             album: this.playerStatus.current.albumName, album_id: this.playerStatus.current.album_id };
        },
        trackInfo() {
            this.info.show=false;
            if (this.desktop) {
                bus.$emit('trackInfo', {id: "track_id:"+this.playerStatus.current.id, title:this.playerStatus.current.title});
            } else {
                this.$router.push('/browse');
                this.$nextTick(function () {
                    bus.$emit('trackInfo', {id: "track_id:"+this.playerStatus.current.id, title:this.playerStatus.current.title});
                });
            }
        },
        fetchLyrics() {
            if (this.info.tabs[LYRICS_TAB].artist!=this.infoTrack.artist || this.info.tabs[LYRICS_TAB].songtitle!=this.infoTrack.title ||
                (this.infoTrack.artist_id && this.info.tabs[LYRICS_TAB].artist_id!=this.infoTrack.artist_id)) {
                this.info.tabs[LYRICS_TAB].text=i18n("Fetching...");
                this.info.tabs[LYRICS_TAB].artist=this.infoTrack.artist;
                this.info.tabs[LYRICS_TAB].artist_id=this.infoTrack.artist_id;
                this.info.tabs[LYRICS_TAB].songtitle=this.infoTrack.title;
                var command = ["musicartistinfo", "lyrics", "title:"+this.infoTrack.title, "html:1"];
                if (this.infoTrack.artist_id) {
                    command.push("artist_id:"+this.infoTrack.artist_id);
                }
                if (!this.infoTrack.artist_ids || this.infoTrack.artist_ids.split(", ").length==1) {
                    command.push("artist:"+this.infoTrack.artist);
                }
                lmsCommand("", command).then(({data}) => {
                    if (data && data.result && (data.result.lyrics || data.result.error)) {
                        this.info.tabs[LYRICS_TAB].text=data.result.lyrics ? replaceNewLines(data.result.lyrics) : data.result.error;
                    }
                });
            }
        },
        fetchBio() {
            if (this.info.tabs[BIO_TAB].artist!=this.infoTrack.artist ||
                (this.infoTrack.artist_id && this.info.tabs[BIO_TAB].artist_id!=this.infoTrack.artist_id)) {
                this.info.tabs[BIO_TAB].text=i18n("Fetching...");
                this.info.tabs[BIO_TAB].artist=this.infoTrack.artist;
                this.info.tabs[BIO_TAB].artist_id=this.infoTrack.artist_id;

                var ids = this.infoTrack.artist_ids ? this.infoTrack.artist_ids.split(", ") : [];
                if (ids.length>1) {
                    this.info.tabs[BIO_TAB].first = true;
                    this.info.tabs[BIO_TAB].found = false;
                    this.info.tabs[BIO_TAB].count = ids.length;
                    for (var i=0; i<ids.length; ++i) {
                        lmsCommand("", ["musicartistinfo", "biography", "artist_id:"+ids[i], "html:1"]).then(({data}) => {
                            if (data && data.result && (data.result.biography || data.result.error)) {
                                if (data.result.artist) {
                                    this.info.tabs[BIO_TAB].found = true;
                                    if (this.info.tabs[BIO_TAB].first) {
                                        this.info.tabs[BIO_TAB].text="";
                                        this.info.tabs[BIO_TAB].first = false;
                                    } else {
                                        this.info.tabs[BIO_TAB].text+="<br/><br/>";
                                    }
                                    this.info.tabs[BIO_TAB].text+="<b>"+data.result.artist+"</b><br/>"+(data.result.biography ? replaceNewLines(data.result.biography) : data.result.error);
                                }
                            }
                            this.info.tabs[BIO_TAB].count--;
                            if (0 == this.info.tabs[BIO_TAB].count && !this.info.tabs[BIO_TAB].found) {
                                this.info.tabs[BIO_TAB].text = i18n("No artist found");
                            }
                        });
                    }
                } else {
                    var command = ["musicartistinfo", "biography", "html:1"];
                    if (this.infoTrack.artist_id) {
                        command.push("artist_id:"+this.infoTrack.artist_id);
                    }
                    if (!this.infoTrack.artist_ids || this.infoTrack.artist_ids.split(", ").length==1) {
                        command.push("artist:"+this.infoTrack.artist);
                    }
                    lmsCommand("", command).then(({data}) => {
                        if (data && data.result && (data.result.biography || data.result.error)) {
                            this.info.tabs[BIO_TAB].text=data.result.biography ? replaceNewLines(data.result.biography) : data.result.error;
                        }
                    });
                }
            }
        },
        fetchReview() {
            if (this.info.tabs[REVIEW_TAB].albumartist!=this.infoTrack.albumartist || this.info.tabs[REVIEW_TAB].album!=this.infoTrack.album ||
                (this.infoTrack.albumartist_ids && this.info.tabs[REVIEW_TAB].albumartist_ids!=this.infoTrack.albumartist_ids) ||
                (this.infoTrack.album_id && this.info.tabs[REVIEW_TAB].album_id!=this.infoTrack.album_id)) {
                this.info.tabs[REVIEW_TAB].text=i18n("Fetching...");
                this.info.tabs[REVIEW_TAB].albumartist=this.infoTrack.albumartist;
                this.info.tabs[REVIEW_TAB].albumartist_ids=this.infoTrack.albumartist_ids;
                this.info.tabs[REVIEW_TAB].album=this.infoTrack.album;
                this.info.tabs[REVIEW_TAB].artist_id=this.infoTrack.artist_id;
                this.info.tabs[REVIEW_TAB].album_id=this.infoTrack.album_id;
                var command = ["musicartistinfo", "albumreview", "html:1"];
                if (this.infoTrack.albumartist_ids) {
                    command.push("artist_id:"+this.infoTrack.albumartist_ids.split(", ")[0]);
                } else if (this.infoTrack.artist_id) {
                    command.push("artist_id:"+this.infoTrack.artist_id);
                }
                if (this.infoTrack.albumartist) {
                    command.push("artist:"+this.infoTrack.albumartist);
                } else if (this.infoTrack.artist) {
                    command.push("artist:"+this.infoTrack.artist);
                }
                if (this.infoTrack.album_id) {
                    command.push("album_id:"+this.infoTrack.album_id);
                }
                command.push("album:"+this.infoTrack.album);

                lmsCommand("", command).then(({data}) => {
                    if (data && data.result && (data.result.albumreview || data.result.error)) {
                        this.info.tabs[REVIEW_TAB].text=data.result.albumreview ? replaceNewLines(data.result.albumreview) : data.result.error;
                    }
                });
            }
        },
        showInfo() {
            if (!this.info.show || !this.infoTrack) {
                return;
            }
            this.$nextTick(function () {
                var elem = document.getElementById("np-info");
                if (elem) {
                    elem.style.backgroundImage = "url('"+(this.$store.state.infoBackdrop ? this.coverUrl : "") +"')";
                }
            });
            if (this.desktop && !this.showTabs) {
                this.fetchLyrics();
                this.fetchBio();
                this.fetchReview();
            } else if (LYRICS_TAB==this.info.tab) {
                this.fetchLyrics();
            } else if (BIO_TAB==this.info.tab) {
                this.fetchBio();
            } else {
                this.fetchReview();
            }
        },
        startPositionInterval() {
            this.positionInterval = setInterval(function () {
                if (undefined!=this.playerStatus.current.time && this.playerStatus.current.time>=0) {
                    this.playerStatus.current.time += 1;
                    this.setPosition();
                }
            }.bind(this), 1000);
        },
        stopPositionInterval() {
            if (undefined!==this.positionInterval) {
                clearInterval(this.positionInterval);
                this.positionInterval = undefined;
            }
        },
        toggleTime() {
            this.showTotal = !this.showTotal;
            setLocalStorageVal("showTotal", this.showTotal);
        },
        setBgndCover() {
            if (this.page && (!this.desktop || this.largeView)) {
                setBgndCover(this.page, this.$store.state.nowPlayingBackdrop ? this.coverUrl : undefined, this.$store.state.darkUi);
            }
        }
    },
    filters: {
        displayTime: function (value) {
            if (undefined==value || value<=0) {
                return '';
            }
            return formatSeconds(Math.floor(value));
        }
    },
    watch: {
        'info.show': function(val) {
            // Indicate that dialog is/isn't shown, so that swipe is controlled
            bus.$emit('dialogOpen', val, 'info-dialog');
            this.setInfoTrack();
            this.showInfo();
        },
        'info.tab': function(tab) {
            this.showInfo();
        },
        'info.showTabs': function() {
            setLocalStorageVal("showTabs", this.info.showTabs);
        },
        'info.sync': function() {
            setLocalStorageVal("syncInfo", this.info.sync);
            if (this.info.sync) {
                this.setInfoTrack();
                this.showInfo();
            }
        },
        'largeView': function(val) {
            if (val) {
                // Save current style so can reset when largeview disabled
                if (!this.before) {
                    var elem = document.getElementById("np-bar");
                    if (elem) {
                        this.before = elem.style;
                    }
                }
                this.$nextTick(function () {
                    this.page = document.getElementById("np-page");
                    this.setBgndCover();
                });
            } else {
                if (this.before) {
                    this.$nextTick(function () {
                        var elem = document.getElementById("np-bar");
                        if (elem) {
                            elem.style = this.before;
                        }
                    });
                }
                this.page = undefined;
            }
            bus.$emit('largeViewVisible', val);
        }
    },
    computed: {
        infoPlugin() {
            return this.$store.state.infoPlugin
        },
        stopButton() {
            return this.$store.state.stopButton
        },
        techInfo() {
            return this.$store.state.techInfo
        },
        formattedTime() {
            return this.playerStatus && this.playerStatus.current
                        ? !this.showTotal && this.playerStatus.current.time && this.playerStatus.current.duration
                            ? formatSeconds(Math.floor(this.playerStatus.current.time))+" / -"+
                              formatSeconds(Math.floor(this.playerStatus.current.duration-this.playerStatus.current.time))
                            : (this.playerStatus.current.time ? formatSeconds(Math.floor(this.playerStatus.current.time)) : "") +
                              (this.playerStatus.current.time && this.playerStatus.current.duration ? " / " : "") +
                              (this.playerStatus.current.duration ? formatSeconds(Math.floor(this.playerStatus.current.duration)) : "")
                        : undefined;
        }
    },
    beforeDestroy() {
        this.stopPositionInterval();
    }
});
