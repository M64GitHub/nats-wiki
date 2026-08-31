<!-- source: https://github.com/nats-io/natscli/blob/v0.4.0/cli/stream_command.go · fetched 2026-08-31 -->
# natscli v0.4.0 — `nats stream add`: the cross-domain and cross-account prompts

Only the ranges this wiki quotes. The interactive `nats stream add` flow contains a complete
cross-domain / cross-account mirror-and-source builder that no docs page mentions. Apache-2.0.

## `askMirror` — the mirror branch

```go
2932:	askDurable, err := askConfirmation("Configure a custom durable consumer", false)
2933:	fisk.FatalIfError(err, "Could not request mirror details")
2934:	if askDurable {
2935:		mirror.Consumer = &api.StreamConsumerSource{}
2936:
2937:		err = iu.AskOne(&survey.Input{
2938:			Message: "Durable consumer name",
2939:			Help:    "The name of the durable to read messages from",
2940:		}, &mirror.Consumer.Name, survey.WithValidator(survey.Required))
2941:		fisk.FatalIfError(err, "Could not request mirror details")
2942:
2943:		err = iu.AskOne(&survey.Input{
2944:			Message: "Delivery subject",
2945:			Help:    "The delivery subject for the consumer",
2946:		}, &mirror.Consumer.DeliverSubject, survey.WithValidator(survey.Required))
2947:		fisk.FatalIfError(err, "Could not request mirror details")
2948:	}
```

```go
3013:	ok, err = askConfirmation("Import mirror from a different JetStream domain", false)
3014:	fisk.FatalIfError(err, "Could not request mirror details")
3015:	if ok {
3016:		mirror.External = &api.ExternalStream{}
3017:		domainName := ""
3018:		err = iu.AskOne(&survey.Input{
3019:			Message: "Foreign JetStream domain name",
3020:			Help:    "The domain name from where to import the JetStream API",
3021:		}, &domainName, survey.WithValidator(survey.Required))
3022:		fisk.FatalIfError(err, "Could not request mirror details")
3023:		mirror.External.ApiPrefix = fmt.Sprintf("$JS.%s.API", domainName)
3024:
3025:		if !askDurable {
3026:			err = iu.AskOne(&survey.Input{
3027:				Message: "Delivery prefix",
3028:				Help:    "Optional prefix of the delivery subject",
3029:			}, &mirror.External.DeliverPrefix)
3030:			fisk.FatalIfError(err, "Could not request mirror details")
3031:		}
3032:	} else {
3033:		ok, err = askConfirmation("Import mirror from a different account", false)
3034:		fisk.FatalIfError(err, "Could not request mirror details")
3035:
3036:		if ok {
3037:			mirror.External = &api.ExternalStream{}
3038:			err = iu.AskOne(&survey.Input{
3039:				Message: "Foreign account API prefix",
3040:				Help:    "The prefix where the foreign account JetStream API has been imported",
3041:			}, &mirror.External.ApiPrefix, survey.WithValidator(survey.Required))
3042:			fisk.FatalIfError(err, "Could not request mirror details")
3043:
3044:			if !askDurable {
3045:				err = iu.AskOne(&survey.Input{
3046:					Message: "Foreign account delivery prefix",
3047:					Help:    "The prefix where the foreign account JetStream delivery subjects has been imported",
3048:				}, &mirror.External.DeliverPrefix, survey.WithValidator(survey.Required))
3049:				fisk.FatalIfError(err, "Could not request mirror details")
3050:			}
3051:		}
3052:	}
3053:
3054:	return mirror
3055:}
```

## `askSource` — the source branch, same two questions

```go
3057:func (c *streamCmd) askSource(name string, prefix string) *api.StreamSource {
3058:	cfg := &api.StreamSource{Name: name}
```

```go
3141:	ok, err = askConfirmation(fmt.Sprintf("Import %q from a different JetStream domain", name), false)
3142:	fisk.FatalIfError(err, "Could not request source details")
3143:	if ok {
3144:		cfg.External = &api.ExternalStream{}
3145:		domainName := ""
3146:		err = iu.AskOne(&survey.Input{
3147:			Message: fmt.Sprintf("%s foreign JetStream domain name", prefix),
3148:			Help:    "The domain name from where to import the JetStream API",
3149:		}, &domainName, survey.WithValidator(survey.Required))
3150:		fisk.FatalIfError(err, "Could not request source details")
3151:		cfg.External.ApiPrefix = fmt.Sprintf("$JS.%s.API", domainName)
3152:
3153:		if !askDurable {
3154:			err = iu.AskOne(&survey.Input{
3155:				Message: fmt.Sprintf("%s foreign JetStream domain delivery prefix", prefix),
3156:				Help:    "Optional prefix of the delivery subject",
3157:			}, &cfg.External.DeliverPrefix)
3158:			fisk.FatalIfError(err, "Could not request source details")
3159:		}
3160:	} else {
3161:		ok, err = askConfirmation(fmt.Sprintf("Import %q from a different account", name), false)
3162:		fisk.FatalIfError(err, "Could not request source details")
3163:		if !ok {
3164:			return cfg
3165:		}
3166:
3167:		cfg.External = &api.ExternalStream{}
3168:		err = iu.AskOne(&survey.Input{
3169:			Message: fmt.Sprintf("%s foreign account API prefix", prefix),
3170:			Help:    "The prefix where the foreign account JetStream API has been imported",
3171:		}, &cfg.External.ApiPrefix, survey.WithValidator(survey.Required))
3172:		fisk.FatalIfError(err, "Could not request source details")
3173:
3174:		if !askDurable {
3175:			err = iu.AskOne(&survey.Input{
3176:				Message: fmt.Sprintf("%s foreign account delivery prefix", prefix),
3177:				Help:    "The prefix where the foreign account JetStream delivery subjects has been imported",
3178:			}, &cfg.External.DeliverPrefix, survey.WithValidator(survey.Required))
3179:			fisk.FatalIfError(err, "Could not request source details")
3180:		}
3181:	}
3182:	return cfg
```

## Where the values are displayed again

`nats stream info` and `nats stream report` print the prefixes back:

```go
2298:	}
2299:
2300:	if s.External != nil {
2301:		if s.External.ApiPrefix != "" {
2302:			parts = append(parts, fmt.Sprintf("API Prefix: %s", s.External.ApiPrefix))
2303:		}
2304:
2305:		if s.External.DeliverPrefix != "" {
2306:			parts = append(parts, fmt.Sprintf("Delivery Prefix: %s", s.External.DeliverPrefix))
2307:		}
2308:	}
2309:
2310:	if s.Consumer != nil {
```

```go
2426:			cols.AddRow("Last Seen", "never")
2427:		}
2428:
2429:		if s.External != nil {
2430:			cols.AddRow("Ext. API Prefix", s.External.ApiPrefix)
2431:			if s.External.DeliverPrefix != "" {
2432:				cols.AddRow("Ext. Delivery Prefix", s.External.DeliverPrefix)
2433:			}
2434:		}
2435:
2436:		if s.Error != nil {
```

```go
1656:			if s.Mirror.Error != nil {
1657:				apierr = s.Mirror.Error.Error()
1658:			}
1659:
1660:			eApiPrefix := ""
1661:			if s.Mirror.External != nil {
1662:				eApiPrefix = s.Mirror.External.ApiPrefix
1663:			}
1664:
1665:			if c.reportRaw {
1666:				table.AddRow(s.Name, "Mirror", eApiPrefix, s.Mirror.Name, "", s.Mirror.Active, s.Mirror.Lag, apierr)
1667:			} else {
1668:				table.AddRow(s.Name, "Mirror", eApiPrefix, s.Mirror.Name, "", f(s.Mirror.Active), f(s.Mirror.Lag), apierr)
1669:			}
1670:		}
1671:
1672:		for _, source := range s.Sources {
1673:			apierr := ""
1674:			if source != nil && source.Error != nil {
1675:				apierr = source.Error.Error()
1676:			}
1677:
1678:			eApiPrefix := ""
1679:			if source.External != nil {
1680:				eApiPrefix = source.External.ApiPrefix
1681:			}
1682:
1683:			filterSubject := []string{}
1684:
1685:			for _, transform := range source.SubjectTransforms {
1686:				filterSubject = append(filterSubject, fmt.Sprintf("%s to %s", transform.Source, transform.Destination))
1687:			}
1688:
1689:			if len(filterSubject) == 0 && source.FilterSubject != "" {
1690:				filterSubject = append(filterSubject, fmt.Sprintf("%s untransformed", source.FilterSubject))
1691:			}
1692:
1693:			if c.reportRaw {
1694:				table.AddRow(s.Name, "Source", eApiPrefix, source.Name, strings.Join(filterSubject, ", "), source.Active, source.Lag, apierr)
1695:			} else {
1696:				table.AddRow(s.Name, "Source", eApiPrefix, source.Name, strings.Join(filterSubject, ", "), f(source.Active), f(source.Lag), apierr)
1697:			}
1698:
1699:		}
1700:	}
```
