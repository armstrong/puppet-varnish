# This is a basic VCL configuration file for varnish.  See the vcl(7)
# man page for details on VCL syntax and semantics.
#
# Default backend definition.  Set this to point to your content
# server.
#
backend default {
    .host = "127.0.0.1";
    .port = "8080";
}
backend nonexistant {
    .host = "127.0.0.1";
    .port = "31337";
    .probe = {
       .interval = 10s;
       .timeout = 0.3 s;
       .window = 2;
       .threshold = 1;
    }
}

sub vcl_recv {
    set req.grace = 48h;
    if (req.restarts == 0) {
        if (req.http.x-forwarded-for) {
            set req.http.X-Forwarded-For =
            req.http.X-Forwarded-For + ", " + client.ip;
        } else {
            set req.http.X-Forwarded-For = client.ip;
        }
    } else {
        set req.backend = nonexistant;
    }
    if (req.http.If-Modified-Since) {
        remove req.http.If-Modified-Since;
    }
    if (req.http.Accept-Encoding) {
        set req.http.Accept-Encoding = "";
    }
    // Remove has_js and Google Analytics __* cookies.
    set req.http.Cookie = regsuball(req.http.Cookie, "(^|;\s*)(_[_a-z0-9]+|has_js)=[^;]*", "");
    // Remove a ";" prefix, if present.
    set req.http.Cookie = regsub(req.http.Cookie, "^;\s*", "");
    if (req.request != "GET" &&
      req.request != "HEAD" &&
      req.request != "PUT" &&
      req.request != "POST" &&
      req.request != "TRACE" &&
      req.request != "OPTIONS" &&
      req.request != "DELETE") {
        /* Non-RFC2616 or CONNECT which is weird. */
        return (pipe);
    }
    if (req.request != "GET" && req.request != "HEAD") {
        /* We only deal with GET and HEAD by default */
        return (pass);
    }
    if (req.http.Authorization) {
        /* Not cacheable by default */
        return (pass);
    }
    return (lookup);
}

sub vcl_pipe {
    # Note that only the first request to the backend will have
    # X-Forwarded-For set.  If you use X-Forwarded-For and want to
    # have it set for all requests, make sure to have:
    # set bereq.http.connection = "close";
    # here.  It is not set by default as it might break some broken web
    # applications, like IIS with NTLM authentication.
    return (pipe);
}

sub vcl_pass {
    return (pass);
}

sub vcl_hash {
    hash_data(req.url);
    if (req.http.X-Forwarded-Proto) {
        hash_data(req.http.X-Forwarded-Proto);
    }
    if (req.http.host) {
        hash_data(req.http.host);
    } else {
        hash_data(server.ip);
    }
    return (hash);
}

sub vcl_hit {
    return (deliver);
}

sub vcl_miss {
    return (fetch);
}

sub vcl_fetch {
    set beresp.grace = 48h;
    if (beresp.http.X-ESI) {
        set beresp.do_esi = true;
    }
    if (beresp.status == 500 ||
        beresp.status == 502 ||
        beresp.status == 503 ||
        beresp.status == 504) {
        # we got an error, so we're going to restart which will use the
        # permanently unhealthy backend, we set grace here to tell varnish
        # how long to wait before retrying the backend for this url
        set beresp.grace = 300s;
        return (restart);
    }
    if (beresp.ttl <= 0s ||
        beresp.http.Set-Cookie ||
        beresp.http.Vary == "*") {
        /*
         * Mark as "Hit-For-Pass" for the next 2 minutes
         */
        set beresp.ttl = 120 s;
        return (hit_for_pass);
    }
    set beresp.http.X-Request-URL = req.url;
    if (req.http.User-Agent ~ "bot") {
        # don't cache the deep stuff that bots find
        set beresp.ttl = 0s;
    }
    return (deliver);
}

sub vcl_deliver {
    return (deliver);
}

sub vcl_error {
    if (req.restarts < 1) {
        return (restart);
    }
    if (req.url ~ "^/esi/") {
        set obj.http.Content-Type = "text/html; charset=utf-8";
        synthetic {"
        <!--<h1>Error "} + obj.status + " " + obj.response + {"</h1>
        <p>"} + obj.response + {"</p>
        <h3>Guru Meditation:</h3>
        <p>XID: "} + req.xid + {"</p>
        <hr>
        <p>Varnish cache server</p>-->
        "};
    } else {
        set obj.http.Content-Type = "text/html; charset=utf-8";
        synthetic {"
<!DOCTYPE html>
<!--[if lt IE 7 ]> <html class="ie6 lte9 no-js" lang="en"> <![endif]-->
<!--[if IE 7 ]>    <html class="ie7 lte9 no-js" lang="en"> <![endif]-->
<!--[if IE 8 ]>    <html class="ie8 lte9 no-js" lang="en"> <![endif]-->
<!--[if (gte IE 9)|!(IE)]><!--> <html class="no-js" lang="en"> <!--<![endif]-->
    <head>
        <title>The Texas Tribune</title>
        <meta name="author" content="The Texas Tribune" />
        <meta name="copyright" content="&copy; The Texas Tribune" />
        <meta name="language" content="EN" />
        <meta name="audience" content="All" />
        <meta name="publisher" content="The Texas Tribune" />
        <meta name="distribution" content="global" />
        <meta name="robots" content="index,follow" />
        <meta name="siteinfo" content="http://www.texastribune.org/robots.txt" />
        <meta name="google-site-verification" content="2RECdeH7aeA9-RQoGzkfTpP5i_3Qz4rtBIR-CdCtvus" />
        <meta name="google-site-verification" content="J3bQZZTiJ8ddCsOBJnUChqtfIaqheKJ06n5vZQgt9I8" /><!-- bluemoonworks -->
        <meta name="y_key" content="36169ff9ee60f3ab" />
        <meta name="msvalidate.01" content="DB22C31255557D1E219990CA92192CBB" />
        <link rel="apple-touch-icon" href="http://static.texastribune.org/common/images/apple-touch-icon.png" />
        <meta property="og:site_name" content="The Texas Tribune" />
        <meta property="fb:admins" content="201781,817029297,699869688" />
        <meta property="fb:app_id" content="154122474650943" />
        <!--[if IE]>
            <meta http-equiv="X-UA-Compatible" content="IE=edge,chrome=1" />
            <script type="text/javascript" src="http://ajax.googleapis.com/ajax/libs/chrome-frame/1/CFInstall.min.js"></script>
        <![endif]-->
        <meta name="medium" content="news" />
        <link rel="shortcut icon" href="http://static.texastribune.org/common/images/favicon.ico" type="image/x-icon">
<!--[if IE]>
  <script src="http://static.texastribune.org/common/js/html5.js"></script>
<![endif]-->
        <link rel="stylesheet" href="https://d2o6nd3dubbyr6.cloudfront.net/COMPRESSED/css/5667fb9fdfa4.css" type="text/css">
            <script src='http://partner.googleadservices.com/gampad/google_service.js'></script>
            <script>
              try {
                  GS_googleAddAdSenseService("ca-pub-1954117026216857");
                  GS_googleEnableAllServices();
              }
              catch(e){ }
            </script>
            <script>
            try {
GA_googleAddSlot("ca-pub-1954117026216857", "TexasTribune_Site_Header_ATF_Rectangle_120x60");
GA_googleAddSlot("ca-pub-1954117026216857", "TexasTribune_Site_Roofline1_ATF_Leaderboard_728x90");
GA_googleAddSlot("ca-pub-1954117026216857", "TexasTribune_Site_Roofline2_ATF_Leaderboard_728x90");
GA_googleAddSlot("ca-pub-1954117026216857", "TexasTribune_Site_Roofline3_ATF_Leaderboard_728x90");
GA_googleAddSlot("ca-pub-1954117026216857", "TexasTribune_Site_Roofline4_ATF_Leaderboard_728x90");
            }
            catch(e) { }
            try {
            }
            catch(e) { }
            </script>
            <script>
              try {
                  GA_googleFetchAds();
              }
              catch(e){ }
            </script>
        <script type="text/javascript" src="//ajax.googleapis.com/ajax/libs/jquery/1.5.2/jquery.min.js"></script>
        <script>window.jQuery || document.write('<script src="http://static.texastribune.org/common/vendor/jquery/jquery-1.5.2.min.js">\x3C/script>')</script>
        <script type="text/javascript" src="//ajax.googleapis.com/ajax/libs/jqueryui/1.8.2/jquery-ui.min.js"></script>
        <script>window.jQuery.ui || document.write('<script src="http://static.texastribune.org/common/vendor/jqueryui/jquery-ui-1.8.2.min.js">\x3C/script>')</script>
        <script type="text/javascript">$('html').removeClass('no-js');</script>
<style type="text/css">
.center { margin: 4em 0; text-align: center; }
</style>
    </head>
    <body class="">
        <!-- Chartbeat -->
<script type="text/javascript">var _sf_startpt=(new Date()).getTime()</script>
        <!-- Analytics -->
        <script type="text/javascript">
            var _gaq = _gaq || [];
            _gaq.push(['_setAccount', 'UA-9827490-1']);
            _gaq.push(['_setCustomVar', 5, 'LoggedIn', 'False', 2]);
            _gaq.push(['_trackPageview']);
            (function() {
              var ga = document.createElement('script'); ga.type = 'text/javascript'; ga.async = true;
              ga.src = ('https:' == document.location.protocol ? 'https://ssl' : 'http://www') + '.google-analytics.com/ga.js';
              (document.getElementsByTagName('head')[0] || document.getElementsByTagName('body')[0]).appendChild(ga);
            })();
        </script>
    <section id="site_roofline" style="position:relative;">
    <div class="ad">
        <!-- ca-pub-1954117026216857/TexasTribune_Site_Roofline1_ATF_Leaderboard_728x90 -->
        <script type='text/javascript'>
            try {
                GA_googleFillSlot("TexasTribune_Site_Roofline1_ATF_Leaderboard_728x90");
            }
            catch(e){ }
        </script>
    </div>
    <div class="ad">
        <!-- ca-pub-1954117026216857/TexasTribune_Site_Roofline2_ATF_Leaderboard_728x90 -->
        <script type='text/javascript'>
            try {
                GA_googleFillSlot("TexasTribune_Site_Roofline2_ATF_Leaderboard_728x90");
            }
            catch(e){ }
        </script>
    </div>
    <div class="ad">
        <!-- ca-pub-1954117026216857/TexasTribune_Site_Roofline3_ATF_Leaderboard_728x90 -->
        <script type='text/javascript'>
            try {
                GA_googleFillSlot("TexasTribune_Site_Roofline3_ATF_Leaderboard_728x90");
            }
            catch(e){ }
        </script>
    </div>
    <div class="ad last">
        <!-- ca-pub-1954117026216857/TexasTribune_Site_Roofline4_ATF_Leaderboard_728x90 -->
        <script type='text/javascript'>
            try {
                GA_googleFillSlot("TexasTribune_Site_Roofline4_ATF_Leaderboard_728x90");
            }
            catch(e){ }
        </script>
    </div>
        <noscript></noscript>
    </section>
    <section id="greeting" class="invisible"><br></section>
    <nav id="site_navigation">
<ul class="primary">
    <li id="site_search">
        <form method="get" action="/search/">
            <label for="site_search_q">Enter Search</label>
            <input id="site_search_q" name="q" type="text" value="" placeholder="Search...">
            <input type="image" src="http://static.texastribune.org/common/images/spacer.gif" alt="Do Search">
        </form>
    </li>
    <li class="active"><a href="/">Front Page</a></li>
    <li>
        <a class="topics" href="/topics/" title="Topics">
            Topics
        </a>
    <li>
        <a class="data" href="/library/data/" title="Data">
            Data
        </a>
    </li>
    <li>
        <a class="blogs" href="/blogs/" title="Blogs">
            Blogs
        </a>
    </li>
    <li><a href="/directory/" title="Directory">Directory</a></li>
    <li>
        <a class="multimedia" href="/multimedia/" title="Multimedia">
            Multimedia
        </a>
    </li>
    <li><a href="/events/" title="Events">Events</a></li>
    <li><a href="/texas-weekly/" title="Texas Weekly">Texas Weekly</a></li>
    <li><a id="qrank_menu" href="/qrank/" title="QRANK: The Texas Tribune Edition">QRANK</a></li>
</ul>

<ul class="secondary">
    <li class="super-topics-nav-public-education"><a href="/texas-education/public-education/">Public Ed</a></li>
    <li class="super-topics-nav-higher-education"><a href="/texas-education/higher-education/">Higher Ed</a></li>
    <li class="super-topics-nav-immigration"><a href="/immigration-in-texas/immigration/">Immigration</a></li>
    <li class="super-topics-nav-health-reform-and-texas"><a href="/texas-health-resources/health-reform-and-texas/">Health Reform</a></li>
    <li class="super-topics-nav-abortion"><a href="/texas-health-resources/abortion-texas/">Abortion</a></li>
    <li class="super-topics-nav-death-penalty"><a href="/texas-dept-criminal-justice/death-penalty/">Death Penalty</a></li>
    <li class="super-topics-nav-energy"><a href="/texas-energy/energy/">Energy</a></li>
    <li class="super-topics-nav-census"><a href="/texas-counties-and-demographics/census/">Census</a></li>
    <li class="super-topics-nav-water-supply"><a href="/texas-environmental-news/water-supply/">Water</a></li>
    <li class="super-topics-nav-2012-elections"><a href="/texas-politics/2012-elections/">2012 Races</a></li>
    <li class="super-topics-nav-perrypedia"><a href="http://www.texastribune.org/perrypedia/">Perrypedia</a></li>
</ul>
    </nav>
    <header id="site_header">
    <div class="ad last">
        <!-- ca-pub-1954117026216857/TexasTribune_Site_Header_ATF_Rectangle_120x60 -->
        <script type='text/javascript'>
            try {
                GA_googleFillSlot("TexasTribune_Site_Header_ATF_Rectangle_120x60");
            }
            catch(e){ }
        </script>
    </div>
        <h1 id="logo"><a href="/"><img src="http://static.texastribune.org/common/images/logo.png" width="453" height="50" alt="The Texas Tribune"></a></h1>
    </header>
    <section id="site_content" class="content">
<div class="center">
    <img src="http://static.texastribune.org/common/images/error_500.gif" alt="Down for maintenance. Dang! We Will Be Back Shortly." width=492 height=198>
</div>
    </section>
    <footer id="site_footer">
<div id="footer" class="auto_height clearfix">
    <dl id="staff_writers">
        <dt>Writers</dt>
            <dd>
                <a href="http://www.texastribune.org/about/staff/becca-aaronson/" class="author">Becca Aaronson</a>
            </dd>
            <dd>
                <a href="http://www.texastribune.org/about/staff/julian-aguilar/" class="author">Julian Aguilar</a>
            </dd>
            <dd>
                <a href="http://www.texastribune.org/about/staff/justin-dehn/" class="author">Justin Dehn</a>
            </dd>
            <dd>
                <a href="http://www.texastribune.org/about/staff/kate-galbraith/" class="author">Kate Galbraith</a>
            </dd>
            <dd>
                <a href="http://www.texastribune.org/about/staff/brandi-grissom/" class="author">Brandi Grissom</a>
            </dd>
            <dd>
                <a href="http://www.texastribune.org/about/staff/reeve-hamilton/" class="author">Reeve Hamilton</a>
            </dd>
            <dd>
                <a href="http://www.texastribune.org/about/staff/mark-miller/" class="author">Mark Miller</a>
            </dd>
            <dd>
                <a href="http://www.texastribune.org/about/staff/ryan-murphy/" class="author">Ryan Murphy</a>
            </dd>
            <dd>
                <a href="http://www.texastribune.org/about/staff/david-muto/" class="author">David Muto</a>
            </dd>
            <dd>
                <a href="http://www.texastribune.org/about/staff/ben-philpott/" class="author">Ben Philpott</a>
            </dd>
            <dd>
                <a href="http://www.texastribune.org/about/staff/ross-ramsey/" class="author">Ross Ramsey</a>
            </dd>
            <dd>
                <a href="http://www.texastribune.org/about/staff/emily-ramshaw/" class="author">Emily Ramshaw</a>
            </dd>
            <dd>
                <a href="http://www.texastribune.org/about/staff/jay-root/" class="author">Jay Root</a>
            </dd>
            <dd>
                <a href="http://www.texastribune.org/about/staff/evan-smith/" class="author">Evan Smith</a>
            </dd>
            <dd>
                <a href="http://www.texastribune.org/about/staff/morgan-smith/" class="author">Morgan Smith</a>
            </dd>
            <dd>
                <a href="http://www.texastribune.org/about/staff/thanh-tan/" class="author">Thanh Tan</a>
            </dd>
    </dl>
    <div id="footer_topics">
        <h6>Topics</h6>
        <ul>
            <li>
                <a href="/texas-taxes/2011-budget-shortfall/" title="">2011 Budget Shortfall</a>
            </li>
            <li>
                <a href="/texas-taxes/rainy-day-fund/" title="">Rainy Day Fund</a>
            </li>
            <li>
                <a href="/texas-mexico-border-news/texas-mexico-border/" title="">Texas-Mexico Border</a>
            </li>
            <li>
                <a href="/texas-legislature/2011-housesenate-transcripts/" title="">82nd Session Transcripts</a>
            </li>
            <li>
                <a href="/texas-representatives-in-congress/tom-delay/" title="">Tom DeLay</a>
            </li>
            <li>
                <a href="/texas-energy/wind-energy/" title="">Wind Energy</a>
            </li>
            <li>
                <a href="/texas-public-records/texas-government-payroll/" title="">Texas Government Payroll</a>
            </li>
            <li>
                <a href="/immigration-in-texas/immigration/" title="">Immigration</a>
            </li>
            <li>
                <a href="/texas-house-of-representatives/2011-house-speakers-race/" title="">2011 House Speaker&#39;s Race</a>
            </li>
            <li>
                <a href="/texas-legislature/texas-legislature/" title="">Texas Legislature</a>
            </li>
        </ul>
        <ul class="last">
            <li>
                <a href="/texas-state-agencies/texas-ethics-commission/" title="">Texas Ethics Commission</a>
            </li>
            <li>
                <a href="/texas-education/higher-education/" title="">Higher Education</a>
            </li>
            <li>
                <a href="/texas-environmental-news/environmental-problems-and-policies/" title="">Environmental Problems and Pol&hellip;</a>
            </li>
            <li>
                <a href="/texas-redistricting/redistricting/" title="">Redistricting</a>
            </li>
            <li>
                <a href="/texas-transportation/texas-department-of-transportation/" title="">Texas Department of Transporta&hellip;</a>
            </li>
            <li>
                <a href="/texas-dept-criminal-justice/death-penalty/" title="">Death Penalty</a>
            </li>
            <li>
                <a href="/texas-politics/voter-id/" title="">Voter ID</a>
            </li>
            <li>
                <a href="/texas-education/social-studies-standards-debate/" title="">Social Studies Standards Debat&hellip;</a>
            </li>
        </ul>
    </div>
    <dl id="offsite_outlets">
        <dt>TT Social Media</dt>
            <dd>
                <a href="http://facebook.com/texastribune" title="Facebook" class="external"><span class="favicon facebook"></span>Facebook</a>
            </dd>
            <dd>
                <a href="http://twitter.com/texastribune" title="Twitter" class="external"><span class="favicon twitter"></span>Twitter</a>
            </dd>
            <dd>
                <a href="http://youtube.com/user/thetexastribune" title="YouTube" class="external"><span class="favicon youtube"></span>YouTube</a>
            </dd>
            <dd>
                <a href="http://vimeo.com/thetexastribune" title="Vimeo" class="external"><span class="favicon vimeo"></span>Vimeo</a>
            </dd>
    </dl>
    <ul id="footer_nav">
        <li>&copy; 2011 The Texas Tribune</li>
        <li>
            <a href="/terms-of-service/" title="Terms of Service">Terms of Service</a>
        </li>
        <li>
            <a href="/privacy/" title="Privacy Policy">Privacy Policy</a>
        </li>
        <li>
            <a href="/about/" title="About Us">About Us</a>
        </li>
        <li>
            <a href="/contact/" title="Contact Us">Contact Us</a>
        </li>
        <li>
            <a href="/feeds/" title="Mobile">Feeds</a>
        </li>
        <li>
            <a href="/channel.html" title="Mobile">Mobile</a>
        </li>
        <li>
            <a href="/support-us/" title="Donate" class="donate">Donate</a>
        </li>
    </ul>
</div>
    </footer>
        <script type="text/javascript" src="https://d2o6nd3dubbyr6.cloudfront.net/COMPRESSED/js/b670a3254fee.js" charset="utf-8"></script>
        <!-- Start Quantcast tag -->
<script type="text/javascript">
    _qoptions={
        qacct:"p-f74d4O38hiiiM"
    };
</script>
    <script type="text/javascript" src="http://edge.quantserve.com/quant.js"></script>
    <noscript>
        <img src="http://pixel.quantserve.com/pixel/p-f74d4O38hiiiM.gif" style="display: none;" border="0" height="1" width="1" alt="Quantcast"/>
    </noscript>
<!-- End Quantcast tag -->
        <script type='text/javascript'>
    var _sf_async_config={};
    /** CONFIGURATION START **/
    _sf_async_config.uid = 14324;
    _sf_async_config.domain = 'texastribune.org';
    if (tt && tt.currentPage) {
        if (tt.currentPage.sections) {
            _sf_async_config.sections = tt.currentPage.sections.join(',');
        }
        if (tt.currentPage.authors) {
            _sf_async_config.authors = tt.currentPage.authors.join(',');
        } else if (tt.currentPage.authorsText) {
            _sf_async_config.authors = tt.currentPage.authorsText;
        }
    }
    /** CONFIGURATION END **/
    (function(){
      function loadChartbeat() {
        window._sf_endpt=(new Date()).getTime();
        var e = document.createElement('script');
        e.setAttribute('language', 'javascript');
        e.setAttribute('type', 'text/javascript');
        e.setAttribute('src',
           (('https:' == document.location.protocol) ? 'https://a248.e.akamai.net/chartbeat.download.akamai.com/102508/' : 'http://static.chartbeat.com/') +
           'js/chartbeat.js');
        document.body.appendChild(e);
      }
      var oldonload = window.onload;
      window.onload = (typeof window.onload != 'function') ?
         loadChartbeat : function() { oldonload(); loadChartbeat(); };
    })();
</script>
    </body>
</html>
        "};
    }
    return (deliver);
}

sub vcl_init {
    return (ok);
}

sub vcl_fini {
    return (ok);
}

